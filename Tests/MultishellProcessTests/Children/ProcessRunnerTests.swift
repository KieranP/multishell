import Foundation
import Synchronization
import TestScratch
import Testing

@testable import MultishellProcess

@Suite
struct ProcessRunnerTests {
  let runner = ProcessRunner()
  let bourneShell = URL(fileURLWithPath: "/bin/sh")
  let workingDirectory = URL(fileURLWithPath: NSTemporaryDirectory())

  @Test func runReturnsWhatTheChildWroteToStandardOutput() async throws {
    let out = try await runner.run(bourneShell, ["-c", "printf hello"], in: workingDirectory)
    #expect(out == "hello")
  }

  @Test func aNonZeroExitThrowsWithStderrAsTheMessage() async {
    let failure = await #expect(throws: ProcessFailure.self) {
      try await runner.run(bourneShell, ["-c", "echo nope >&2; exit 3"], in: workingDirectory)
    }
    #expect(failure?.status == 3)
    #expect(failure?.message == "nope")
    #expect(failure?.executable == "sh")
  }

  @Test func captureReturnsStatusInsteadOfThrowing() async throws {
    let output = try await runner.capture(bourneShell, ["-c", "exit 7"], in: workingDirectory)
    #expect(output.status == 7)
    #expect(!output.succeeded)
  }

  /// The deadlock this guards against: a child that fills both pipes past
  /// 64 KiB blocks forever if the parent drains them one after the other.
  @Test func aChildFillingBothPipesPastTheirBuffersStillFinishes() async throws {
    let output = try await runner.capture(
      bourneShell,
      ["-c", "head -c 300000 /dev/zero | tr '\\0' a; head -c 300000 /dev/zero | tr '\\0' b >&2"],
      in: workingDirectory,
    )
    #expect(output.standardOutput.count == 300_000)
    #expect(output.standardError.count == 300_000)
  }

  /// Starved, the cooperative pool holds at most a thread per core inside a run, so each child
  /// counts the runs beside it instead of timing the batch; see Docs/develop/tests.md.
  @Test func manyConcurrentProcessesDoNotStarveEachOther() async throws {
    let running = try Scratch.directory("overlap")
    defer { Scratch.remove(running) }
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
          let seen = try await runner.run(bourneShell, ["-c", script], in: workingDirectory)
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
      bourneShell,
      ["-c", "printf \"$MULTISHELL_TEST-$HOME\""],
      in: workingDirectory,
      environment: ["MULTISHELL_TEST": "yes"],
    )
    #expect(out.hasPrefix("yes-/"))
  }

  @Test func aChildStartsInTheDirectoryItIsGiven() async throws {
    let directory = try Scratch.directory("start-here")
    defer { Scratch.remove(directory) }
    let out = try await runner.run(bourneShell, ["-c", "pwd -P"], in: directory)
    let started = URL(fileURLWithPath: out.trimmingCharacters(in: .whitespacesAndNewlines))
    #expect(Scratch.physicalPath(of: started) == Scratch.physicalPath(of: directory))
  }

  /// A superseded status refresh cancels its task mid-read; the stopper, not
  /// the task, is what ends a child, or a slow `git status` never lands.
  @Test func cancellingTheTaskThatAwaitsAChildLetsTheChildFinish() async throws {
    let run = Task {
      try await runner.capture(
        bourneShell,
        ["-c", "sleep 0.3; printf done"],
        in: workingDirectory,
      )
    }
    try await Task.sleep(for: .milliseconds(50))
    run.cancel()
    let output = try await run.value

    #expect(output.succeeded, "status \(output.status)")
    #expect(output.standardOutput == "done")
  }

  /// On this process's terminal, an interactive zsh outside the foreground
  /// group stopped itself on SIGTTIN and sat there until the timeout.
  @Test func aChildRunsInASessionOfItsOwnSoNoTerminalCanStopIt() async throws {
    let output = try await runner.capture(
      bourneShell,
      ["-c", "sleep 30 >/dev/null 2>&1 & echo $!"],
      in: workingDirectory,
    )
    let background = try #require(
      pid_t(output.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    )
    defer { kill(background, SIGKILL) }

    #expect(getsid(background) > 0)
    #expect(getsid(background) != getsid(0))
  }

  /// A fork copies the whole app on Subprocess's one spawn thread, and a
  /// refused one is not retried.
  @Test func aChildGetsItsSessionWithoutTheAppForking() async throws {
    ForkCount.watch()
    let before = ForkCount.forks.load(ordering: .relaxed)

    _ = try await runner.capture(bourneShell, ["-c", "true"], in: workingDirectory)

    #expect(ForkCount.forks.load(ordering: .relaxed) == before)
  }

  @Test func aChildThatReadsStdinGetsEOFNotTheApps() async throws {
    let out = try await runner.run(bourneShell, ["-c", "cat; printf done"], in: workingDirectory)
    #expect(out == "done")
  }
}
