import Foundation
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

  /// Blocking waits inside a `Task` occupy the cooperative pool, one thread
  /// per core; ninety-six such waits ran in a dozen rounds here and would
  /// take forty-eight, twelve seconds, on a two-core runner. Without any
  /// blocked thread they all overlap and finish together.
  @Test func manyConcurrentProcessesDoNotStarveEachOther() async throws {
    let started = ContinuousClock.now
    try await withThrowingTaskGroup(of: String.self) { group in
      for _ in 0..<96 {
        group.addTask { try await runner.run(sh, ["-c", "sleep 0.25; printf done"], in: cwd) }
      }
      for try await output in group {
        #expect(output == "done")
      }
    }
    let elapsed = ContinuousClock.now - started
    #expect(elapsed < .seconds(3), "took \(elapsed)")
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
}

@Suite
struct ShellCommandTests {
  @Test func runsACommandLineThroughTheShellWithEnvironment() async throws {
    let out = try await ShellCommand().run(
      "echo $MULTISHELL_BRANCH | tr a-z A-Z", in: URL(fileURLWithPath: NSTemporaryDirectory()),
      environment: ["MULTISHELL_BRANCH": "feat"])
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "FEAT")
  }
}

@Suite
struct ExecutableLookupTests {
  @Test func findsToolsOnPath() {
    #expect(ExecutableLookup.find("sh") != nil)
    #expect(ExecutableLookup.find("git") != nil)
  }

  @Test func returnsNilForMissingTools() {
    #expect(ExecutableLookup.find("definitely-not-a-real-binary-\(UUID().uuidString)") == nil)
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

  /// The status poll hits this every five seconds for a worktree on an
  /// unmounted drive; each failure used to keep six descriptors open forever.
  ///
  /// The count is process-wide and other suites open hundreds of descriptors
  /// while this runs, so each side is the lowest of several readings: the
  /// noise is transient, the leak is not.
  @Test func failedLaunchesDoNotLeakFileDescriptors() async throws {
    let runner = ProcessRunner()
    func lowestDescriptorCount(over samples: Int) async throws -> Int {
      var lowest = Int.max
      for _ in 0..<samples {
        lowest = min(lowest, try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count)
        try await Task.sleep(for: .milliseconds(40))
      }
      return lowest
    }
    func failToLaunch() async {
      _ = try? await runner.run(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "true"], in: URL(fileURLWithPath: "/no/such/dir"))
    }

    for _ in 0..<5 { await failToLaunch() }
    let before = try await lowestDescriptorCount(over: 5)
    for _ in 0..<100 { await failToLaunch() }
    let after = try await lowestDescriptorCount(over: 10)

    #expect(after - before < 300, "before \(before), after \(after); the leak was 600")
  }
}
