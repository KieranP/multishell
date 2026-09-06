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

@Suite
struct ProcessRunnerCompletionTests {
  private let runner = ProcessRunner()
  private let sh = URL(fileURLWithPath: "/bin/sh")
  private let cwd = URL(fileURLWithPath: NSTemporaryDirectory())

  /// A hook like `npm run dev &` exits at once but its child inherits the
  /// pipes, so EOF never comes while the server runs. The call must return
  /// when the process the caller started exits, not when its descendants do.
  @Test func aChildThatExitsWithABackgroundGrandchildStillCompletes() async throws {
    let started = ContinuousClock.now
    let output = try await runner.capture(
      sh, ["-c", "printf before; sleep 4 & exit 0"], in: cwd)
    let elapsed = ContinuousClock.now - started

    #expect(output.succeeded)
    #expect(output.standardOutput == "before")
    #expect(elapsed < .seconds(3), "waited on the grandchild: \(elapsed)")
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

  /// Each run opens two pipes, four descriptors. The status poll runs one
  /// per worktree every five seconds, so a leak here would exhaust the
  /// process within the hour.
  @Test func successfulRunsDoNotLeakFileDescriptors() async throws {
    func lowestDescriptorCount(over samples: Int) async throws -> Int {
      var lowest = Int.max
      for _ in 0..<samples {
        lowest = min(lowest, try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count)
        try await Task.sleep(for: .milliseconds(40))
      }
      return lowest
    }
    for _ in 0..<5 { _ = try await runner.run(sh, ["-c", "printf x"], in: cwd) }
    let before = try await lowestDescriptorCount(over: 5)
    for _ in 0..<100 { _ = try await runner.run(sh, ["-c", "printf x; printf y >&2"], in: cwd) }
    let after = try await lowestDescriptorCount(over: 10)

    #expect(after - before < 100, "before \(before), after \(after); a leak would be 400")
  }
}

/// Lowering the process-wide descriptor limit starves every other suite
/// running alongside, so this runs only when asked:
///
///     MULTISHELL_EXHAUST_DESCRIPTORS=1 swift test --filter DescriptorExhaustionTests
@Suite(.serialized)
struct DescriptorExhaustionTests {
  @Test(.enabled(if: ProcessInfo.processInfo.environment["MULTISHELL_EXHAUST_DESCRIPTORS"] != nil))
  func atTheDescriptorLimitARunThrowsInsteadOfReadingTheAppsStdin() async throws {
    // libdispatch raises the soft limit the first time a process creates a
    // file source. Make that happen now, or it happens inside the runner and
    // undoes the shortage this test sets up.
    let warmUp = FileHandle(fileDescriptor: 2, closeOnDealloc: false)
    warmUp.readabilityHandler = { _ in }
    warmUp.readabilityHandler = nil

    var saved = rlimit()
    getrlimit(RLIMIT_NOFILE, &saved)
    var held: [Int32] = []
    defer {
      var restore = saved
      setrlimit(RLIMIT_NOFILE, &restore)
      for fd in held { close(fd) }
    }

    // Take every descriptor up to a limit just above what is open now.
    let inUse = try FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count
    var lowered = saved
    lowered.rlim_cur = rlim_t(inUse + 8)
    #expect(setrlimit(RLIMIT_NOFILE, &lowered) == 0)
    while true {
      let fd = open("/dev/null", O_RDONLY)
      if fd < 0 { break }
      held.append(fd)
    }

    let runner = ProcessRunner()
    let cwd = URL(fileURLWithPath: NSTemporaryDirectory())
    do {
      let output = try await runner.capture(
        URL(fileURLWithPath: "/bin/sh"), ["-c", "printf real"], in: cwd)
      Issue.record("ran with output \(output.standardOutput.debugDescription) at the limit")
    } catch is PipeUnavailable {
      // What we want: a loud failure the caller reports.
    } catch {
      Issue.record("wrong error: \(error)")
    }

    var restore = saved
    setrlimit(RLIMIT_NOFILE, &restore)
    for fd in held { close(fd) }
    held = []
    let output = try await runner.run(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "printf ok"], in: cwd)
    #expect(output == "ok", "works again once descriptors are back")
  }
}

@Suite
struct HookShellTests {
  /// Hooks must see the PATH a terminal sees. The shell's rc files under a
  /// substitute home each export a marker; whichever shell `$SHELL` is, the
  /// hook must see one of them. Written for zsh, bash and sh; another shell
  /// only has to run the command.
  @Test func aHookRunsInTheUsersInteractiveLoginShell() async throws {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-home-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    for (file, marker) in [
      (".zshrc", "zshrc"), (".zprofile", "zprofile"), (".bashrc", "bashrc"),
      (".bash_profile", "bash_profile"), (".profile", "profile"),
    ] {
      try "export MULTISHELL_RC=\(marker)\n".write(
        to: home.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    let out = try await ShellCommand().run(
      "printf '%s' \"$MULTISHELL_RC\"", in: home, environment: ["HOME": home.path])

    let shell = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SHELL"] ?? "")
      .lastPathComponent
    if ["zsh", "bash", "sh"].contains(shell) {
      #expect(!out.isEmpty, "a hook under \(shell) saw none of the rc files")
    }
  }

  @Test func aChildThatReadsStdinGetsEOFNotTheApps() async throws {
    let out = try await ProcessRunner().run(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "cat; printf done"],
      in: URL(fileURLWithPath: NSTemporaryDirectory()))
    #expect(out == "done")
  }

  @Test func aScriptStopsAtItsFirstFailingLineWhereTheShellCanBeTold() async throws {
    let scratch = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-script-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratch) }

    let shell = ShellCommand.shell!.executable.lastPathComponent
    guard ShellCommand.errexitShells.contains(shell) else { return }
    await #expect(throws: ProcessFailure.self) {
      try await ShellCommand().runScript(
        "echo one > first.txt\nfalse\necho two > second.txt", in: scratch)
    }
    #expect(
      FileManager.default.fileExists(atPath: scratch.appendingPathComponent("first.txt").path))
    #expect(
      !FileManager.default.fileExists(atPath: scratch.appendingPathComponent("second.txt").path),
      "the line after the failure ran")

    let out = try await ShellCommand().runScript("printf a\nprintf b", in: scratch)
    #expect(out == "ab", "a sound script runs every line")
  }

  /// The user's rc files write to stderr under `-i` with no terminal, and
  /// that noise used to be the whole of a failing hook's message when the
  /// hook itself printed little or nothing.
  @Test func aFailingScriptsMessageIsItsOwnStderrNotTheRcFiles() async throws {
    let home = URL(fileURLWithPath: NSTemporaryDirectory())
      .appendingPathComponent("multishell-home-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    for file in [".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile"] {
      try "echo 'rc noise' >&2\n".write(
        to: home.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }
    let shell = ShellCommand.shell!.executable.lastPathComponent
    guard ShellCommand.markingShells.contains(shell) else { return }

    let cases: [(script: String, message: String)] = [
      ("echo 'the hook said so' >&2\nexit 3", "the hook said so"),
      ("exit 3", ""),
      ("echo hey\necho 'and then' >&2\nexit 3", "hey\nand then"),
      ("echo hey\nexit 3", "hey"),
    ]
    for (script, message) in cases {
      do {
        _ = try await ShellCommand().runScript(script, in: home, environment: ["HOME": home.path])
        Issue.record("the script did not fail")
      } catch let failure as ProcessFailure {
        #expect(failure.status == 3)
        #expect(!failure.message.contains("rc noise"), "\(script): \(failure.message)")
        #expect(failure.message == message, "\(script): \(failure.message)")
      }
    }
  }

  @Test func aFailureMessageIsStdoutThenTheScriptsStderr() {
    let marker = ShellCommand.outputMarker
    #expect(
      ShellCommand.failureMessage(standardOutput: "hey\n", standardError: "noise\n\(marker)\nbad\n")
        == "hey\nbad")
    #expect(
      ShellCommand.failureMessage(standardOutput: "", standardError: "\(marker)\n") == "",
      "silent")
    #expect(ShellCommand.failureMessage(standardOutput: "  hey  ", standardError: "") == "hey")
  }

  @Test func theMarkerSplitsStderrAndIsWrittenForShellsThatTakeTheRedirect() {
    let marker = ShellCommand.outputMarker
    #expect(ShellCommand.scriptOutput(fromStderr: "noise\n\(marker)\nmine\n") == "mine")
    #expect(ShellCommand.scriptOutput(fromStderr: "noise\n\(marker)\n") == "")
    #expect(ShellCommand.scriptOutput(fromStderr: "no marker here") == "no marker here")
    #expect(
      ShellCommand.markingOutput("a", shell: URL(fileURLWithPath: "/bin/zsh"))
        == "printf '%s\\n' '\(marker)' >&2\na")
    #expect(
      ShellCommand.markingOutput("a", shell: URL(fileURLWithPath: "/opt/homebrew/bin/fish"))
        .hasPrefix("printf"))
    #expect(
      ShellCommand.markingOutput("a", shell: URL(fileURLWithPath: "/bin/tcsh")) == "a",
      "csh has no >&2")
  }

  @Test func errexitIsPrependedForThePosixFamilyOnly() {
    #expect(
      ShellCommand.stoppingAtFirstFailure("a\nb", shell: URL(fileURLWithPath: "/bin/zsh"))
        == "set -e\na\nb")
    #expect(
      ShellCommand.stoppingAtFirstFailure("a\nb", shell: URL(fileURLWithPath: "/bin/sh"))
        == "set -e\na\nb")
    #expect(
      ShellCommand.stoppingAtFirstFailure(
        "a\nb", shell: URL(fileURLWithPath: "/opt/homebrew/bin/fish"))
        == "a\nb", "fish's set -e erases a variable")
    #expect(
      ShellCommand.stoppingAtFirstFailure("a", shell: URL(fileURLWithPath: "/bin/tcsh")) == "a")
  }

  @Test func onlyKnownShellsGetTheInteractiveLoginFormOthersFallBackToSh() {
    #expect(ShellCommand.shell(named: "/bin/zsh").arguments == ["-l", "-i", "-c"])
    #expect(ShellCommand.shell(named: "/bin/zsh").executable.path == "/bin/zsh")
    for odd in ["/usr/local/bin/nu", "/opt/homebrew/bin/xonsh", "/no/such/zsh", "", nil] {
      let fallback = ShellCommand.shell(named: odd)
      #expect(fallback.executable.path == "/bin/sh", "\(odd ?? "nil")")
      #expect(fallback.arguments == ["-c"], "\(odd ?? "nil")")
    }
    #expect(ShellCommand.shell != nil)
  }
}
