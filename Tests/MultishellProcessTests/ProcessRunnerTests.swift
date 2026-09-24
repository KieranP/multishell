import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessRunnerTests {
  private let runner = ProcessRunner()
  private let sh = URL(fileURLWithPath: "/bin/sh")
  private let cwd = URL(fileURLWithPath: NSTemporaryDirectory())

  @Test func capturesStandardOutput() async throws {
    let out = try await runner.run(sh, ["-c", "printf hello"], in: cwd)
    #expect(out == "hello")
  }

  @Test func aNonZeroExitThrowsWithStderrAsTheMessage() async {
    await #expect(throws: ProcessFailure.self) {
      try await runner.run(sh, ["-c", "echo nope >&2; exit 3"], in: cwd)
    }
    do {
      _ = try await runner.run(sh, ["-c", "echo nope >&2; exit 3"], in: cwd)
    } catch let failure as ProcessFailure {
      #expect(failure.status == 3)
      #expect(failure.message == "nope")
      #expect(failure.executable == "sh")
    } catch {
      Issue.record("wrong error type: \(error)")
    }
  }

  @Test func captureReturnsStatusInsteadOfThrowing() async throws {
    let output = try await runner.capture(sh, ["-c", "exit 7"], in: cwd)
    #expect(output.status == 7)
    #expect(!output.succeeded)
  }

  /// The deadlock this guards against: a child that fills both pipes past
  /// 64 KiB blocks forever if the parent drains them one after the other.
  @Test func drainsLargeOutputOnBothPipesWithoutDeadlocking() async throws {
    let output = try await runner.capture(
      sh,
      ["-c", "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b >&2"],
      in: cwd
    )
    #expect(output.standardOutput.count == 300_000)
    #expect(output.standardError.count == 300_000)
  }

  /// Starved, the cooperative pool holds at most a thread per core inside a run, so each child
  /// counts the runs beside it instead of timing the batch; see Docs/develop/tests.md.
  @Test func manyConcurrentProcessesDoNotStarveEachOther() async throws {
    let running = cwd.appendingPathComponent("ms-overlap-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: running, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: running) }
    let script = """
      : > "\(running.path)/$$"
      ls "\(running.path)" | wc -l
      sleep 1
      rm "\(running.path)/$$"
      """

    let cores = ProcessInfo.processInfo.activeProcessorCount
    let children = max(96, cores * 4)
    let peaks = try await withThrowingTaskGroup(of: Int.self) { group in
      for _ in 0..<children {
        group.addTask {
          let seen = try await runner.run(sh, ["-c", script], in: cwd)
          return Int(seen.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        }
      }
      return try await group.reduce(into: [Int]()) { $0.append($1) }
    }

    #expect(peaks.count == children, "every run reported")
    #expect(peaks.max() ?? 0 > cores * 2, "\(cores) cores, and at most \(peaks.max() ?? 0) ran")
  }

  @Test func extraEnvironmentIsMergedOverTheParents() async throws {
    let out = try await runner.run(
      sh, ["-c", "printf \"$MULTISHELL_TEST-$HOME\""], in: cwd,
      environment: ["MULTISHELL_TEST": "yes"])
    #expect(out.hasPrefix("yes-/"))
  }

  @Test func runsInTheGivenDirectory() async throws {
    let out = try await runner.run(sh, ["-c", "pwd"], in: cwd)
    #expect(
      URL(fileURLWithPath: out.trimmingCharacters(in: .whitespacesAndNewlines)).standardizedFileURL
        .path
        == cwd.standardizedFileURL.path.replacingOccurrences(of: "/private", with: "")
        || out.contains(cwd.lastPathComponent))
  }

  /// On this process's terminal, an interactive zsh outside the foreground
  /// group stopped itself on SIGTTIN and sat there until the timeout.
  @Test func aChildRunsInASessionOfItsOwnSoNoTerminalCanStopIt() async throws {
    let output = try await runner.capture(
      sh, ["-c", "sleep 30 >/dev/null 2>&1 & echo $!"], in: cwd)
    let background = try #require(
      pid_t(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)))
    defer { kill(background, SIGKILL) }

    #expect(getsid(background) > 0)
    #expect(getsid(background) != getsid(0))
  }
}

@Suite
struct ProcessRunnerFailureTests {
  @Test func aMissingExecutableThrowsBeforeAnythingRuns() async {
    let runner = ProcessRunner()
    await #expect(throws: (any Error).self) {
      try await runner.run(
        URL(fileURLWithPath: "/no/such/binary"), [],
        in: URL(fileURLWithPath: NSTemporaryDirectory()))
    }
  }

  @Test func aMissingWorkingDirectoryThrows() async {
    let runner = ProcessRunner()
    await #expect(throws: (any Error).self) {
      try await runner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }
  }

  /// Each failure used to leak six descriptors, every five seconds on an unmounted drive. Other
  /// suites' descriptors come and go, so each side is the lowest reading over seconds.
  @Test func failedLaunchesDoNotLeakFileDescriptors() async throws {
    let runner = ProcessRunner()
    func failToLaunch() async {
      _ = try? await runner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }

    for _ in 0..<5 { await failToLaunch() }
    let before = try await lowestDescriptorCount(over: .seconds(2))
    for _ in 0..<100 { await failToLaunch() }
    let after = try await lowestDescriptorCount(over: .seconds(4))

    #expect(after - before < 300, "before \(before), after \(after); the leak was 600")
  }
}

@Suite
struct ProcessRunnerCompletionTests {
  private let runner = ProcessRunner()
  private let sh = URL(fileURLWithPath: "/bin/sh")
  private let cwd = URL(fileURLWithPath: NSTemporaryDirectory())

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
