import Foundation
import Synchronization
import System
import TestScratch
import Testing

@testable import MultishellProcess

extension ProcessRunnerTests {
  /// `npm run dev &` exits at once but its child keeps the pipes, so EOF never comes. A clock
  /// bound flaked on CI, so the proof is the grandchild still alive when the call returns.
  @Test func aChildThatExitsWithABackgroundGrandchildStillCompletes() async throws {
    let output = try await runner.capture(
      sh, ["-c", "printf before; sleep 60 & echo $! >&2; exit 0"], in: cwd)
    let grandchild = try #require(
      pid_t(output.standardError.trimmingCharacters(in: .whitespacesAndNewlines)))
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
        sh, ["-c", "head -c 200000 /dev/zero | tr '\\0' x; printf tail >&2"], in: cwd)
      #expect(output.standardOutput.count == 200_000)
      #expect(output.standardError == "tail")
    }
  }

  @Test func aRunLetsGoOfItsPipesWhenItReturnsNotASecondLater() async throws {
    let group = DispatchGroup()
    let (outPipe, errPipe) = (try PipeBuffer.makePipe(), try PipeBuffer.makePipe())
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

    await ProcessRunner.drain(try #require(out), try #require(err), group: group)
    out = nil
    err = nil

    #expect(releasedOut == nil)
    #expect(releasedErr == nil)
  }

  /// Each run opens four descriptors, and the status poll runs one per worktree every five
  /// seconds, so a leak here would exhaust the process within the hour.
  @Test func successfulRunsDoNotLeakFileDescriptors() async throws {
    for _ in 0..<5 { _ = try await runner.run(sh, ["-c", "printf x"], in: cwd) }
    let before = try await lowestDescriptorCount(over: .seconds(2))
    for _ in 0..<100 { _ = try await runner.run(sh, ["-c", "printf x; printf y >&2"], in: cwd) }
    let after = try await lowestDescriptorCount(over: .seconds(4))

    #expect(after - before < 100, "before \(before), after \(after); a leak would be 400")
  }
}
