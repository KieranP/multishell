import Foundation
import Synchronization
import System
import Testing

@testable import MultishellProcess

extension ProcessRunnerTests {
  /// `npm run dev &` exits at once but its child keeps the pipes, so EOF never comes. A clock
  /// bound flaked on CI, so the proof is the grandchild still alive when the call returns.
  @Test func aChildThatExitsWithABackgroundGrandchildStillCompletes() async throws {
    let output = try await runner.capture(
      bourneShell,
      ["-c", "printf before; sleep 60 & echo $! >&2; exit 0"],
      in: workingDirectory,
    )
    let grandchild = try #require(
      pid_t(output.standardError.trimmingCharacters(in: .whitespacesAndNewlines))
    )
    defer { kill(grandchild, SIGKILL) }

    #expect(output.succeeded)
    #expect(output.standardOutput == "before")
    #expect(kill(grandchild, 0) == 0, "waited on the grandchild until it exited")
  }

  /// Output written right before exit sits in the pipe when the exit is
  /// noticed; completing on exit must not lose it.
  @Test func outputWrittenJustBeforeExitIsKept() async throws {
    for _ in 0..<20 {
      let output = try await runner.capture(
        bourneShell,
        ["-c", "head -c 200000 /dev/zero | tr '\\0' x; printf tail >&2"],
        in: workingDirectory,
      )
      #expect(output.standardOutput.count == 200_000)
      #expect(output.standardError == "tail")
    }
  }

  /// Foundation drops a cleared readability handler later, on its own queue; holding the
  /// buffer strongly, it kept 35 to 40 runs in a thousand alive past the return.
  @Test func aRunLetsGoOfItsPipesWhenItReturnsNotASecondLater() async throws {
    var kept = 0
    for _ in 0..<1000 where try await isKeptAfterDraining() { kept += 1 }

    #expect(kept == 0)
  }

  private func isKeptAfterDraining() async throws -> Bool {
    let group = DispatchGroup()
    let (outPipe, errPipe) = (try PipeDescriptors.make(), try PipeDescriptors.make())
    defer {
      try? outPipe.writing.close()
      try? errPipe.writing.close()
    }
    var out: PipeBuffer? = PipeBuffer(outPipe.reading, group: group)
    var err: PipeBuffer? = PipeBuffer(errPipe.reading, group: group)
    weak let releasedOut = out
    weak let releasedErr = err
    out?.finish()
    err?.finish()

    await ProcessRunner.awaitDrained(try #require(out), try #require(err), group: group)
    out = nil
    err = nil

    return releasedOut != nil || releasedErr != nil
  }

  /// Each run opens four descriptors, and the status poll runs one per worktree every five
  /// seconds, so a leak here would exhaust the process within the hour.
  @Test func successfulRunsDoNotLeakFileDescriptors() async throws {
    for _ in 0..<5 {
      _ = try await runner.run(bourneShell, ["-c", "printf x"], in: workingDirectory)
    }
    let before = try await lowestDescriptorCount(over: .seconds(2))
    for _ in 0..<100 {
      _ = try await runner.run(
        bourneShell,
        ["-c", "printf x; printf y >&2"],
        in: workingDirectory,
      )
    }
    let after = try await lowestDescriptorCount(over: .seconds(4))

    #expect(after - before < 100, "before \(before), after \(after); a leak would be 400")
  }
}

extension ProcessRunnerTests {
  /// Reads blocked on a dead mount hold GCD's constrained threads, and the
  /// global queue then ran no timer: a run's timeout never fired.
  @Test func aTimeoutStillFiresWhileBlockedReadsHoldEveryConstrainedThread() async throws {
    var limit: Int32 = 0
    var size = MemoryLayout<Int32>.size
    try #require(sysctlbyname("kern.wq_max_constrained_threads", &limit, &size, nil, 0) == 0)
    let gate = DispatchSemaphore(value: 0)
    for _ in 0..<limit {
      DispatchQueue.global(qos: .utility).async { _ = gate.wait(timeout: .now() + 30) }
    }
    defer { for _ in 0..<limit { gate.signal() } }

    let output = try await runner.capture(
      bourneShell,
      ["-c", "sleep 5"],
      in: workingDirectory,
      timeout: .milliseconds(500),
    )

    #expect(output.stopReason == .timedOut(after: .milliseconds(500)))
  }
}
