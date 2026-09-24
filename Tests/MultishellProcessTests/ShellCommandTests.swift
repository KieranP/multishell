import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

/// A shell named outright, over a home the test owns, so no test here reads
/// the developer's `$SHELL` or rc files.
struct ScratchShell {
  let path: String
  let home: URL

  init(_ path: String = "/bin/zsh") throws {
    self.path = path
    home = try Scratch.directory("home")
  }

  var environment: [String: String] { ["HOME": home.path, "ZDOTDIR": home.path] }

  func tearDown() {
    try? FileManager.default.removeItem(at: home)
  }
}

@Suite
struct ShellCommandTests {
  @Test func runsACommandLineThroughTheShellWithEnvironment() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let out = try await ShellCommand().runScript(
      "echo $MULTISHELL_BRANCH | tr a-z A-Z", in: shell.home,
      environment: shell.environment.merging(["MULTISHELL_BRANCH": "feat"]) { $1 },
      shellPath: shell.path)
    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "FEAT")
  }

  @Test func aLaunchedCommandSaysHowItEnded() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    func launch(_ command: String, in directory: URL) async throws {
      try await ShellCommand().launch(
        command, in: directory, environment: shell.environment, shellPath: shell.path)
    }
    try await launch("true", in: shell.home)
    await #expect(throws: ProcessFailure.self) {
      try await launch("exit 3", in: shell.home)
    }
    await #expect(throws: (any Error).self) {
      try await launch("true", in: URL(fileURLWithPath: "/no/such/dir"))
    }
  }
  /// A shim holding the editor open holds this call too, which kept two pipes and a login
  /// shell per click; the shell sees a pipe where a descriptor count in this process cannot.
  @Test func aLaunchedCommandIsGivenNoPipes() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    for stream in ["1", "2"] {
      await #expect(throws: ProcessFailure.self, "stream \(stream)") {
        try await ShellCommand().launch(
          "test -p /dev/fd/\(stream)", in: shell.home, environment: shell.environment,
          shellPath: shell.path)
      }
      let captured = try await ShellCommand().runScript(
        "test -p /dev/fd/\(stream) && printf pipe", in: shell.home,
        environment: shell.environment, shellPath: shell.path)
      #expect(captured == "pipe", "which is what `runScript` gives it, for the contrast")
    }
  }
}

@Suite
struct HookShellTests {
  /// Hooks must see the PATH a terminal sees: a login, interactive shell
  /// reads its rc files, each of which exports a marker under this home.
  @Test func aHookRunsInAnInteractiveLoginShellThatReadsItsRcFiles() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    for (file, marker) in [
      (".zshrc", "zshrc"), (".zprofile", "zprofile"), (".bashrc", "bashrc"),
      (".bash_profile", "bash_profile"), (".profile", "profile"),
    ] {
      try "export MULTISHELL_RC=\(marker)\n".write(
        to: home.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    let out = try await ShellCommand().runScript(
      "printf '%s' \"$MULTISHELL_RC\"", in: home,
      environment: ["HOME": home.path, "ZDOTDIR": home.path], shellPath: "/bin/zsh")

    #expect(out == "zshrc", ".zprofile then .zshrc, as a login interactive zsh reads them")
  }

  @Test func aHookRunsInItsDirectoryWhereverTheRcFilesLeftTheShell() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    let worktree = try Scratch.directory("it's here")
    defer { try? FileManager.default.removeItem(at: worktree) }
    try "cd /\nchpwd() { echo noise; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let out = try await ShellCommand().runScript(
      "pwd -P", in: worktree, environment: ["HOME": home.path, "ZDOTDIR": home.path],
      shellPath: "/bin/zsh")

    let expected = try #require(realpath(worktree.path, nil))
    defer { free(expected) }
    #expect(out.trimmingCharacters(in: .newlines) == String(cString: expected))
  }

  @Test func aChpwdHooksStderrIsNotTakenForTheFailingHooksMessage() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    try "chpwd() { echo 'direnv: loading .envrc' >&2; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let failure = await #expect(throws: ProcessFailure.self) {
      try await ShellCommand().runScript(
        "echo 'hook failed' >&2\nexit 3", in: home,
        environment: ["HOME": home.path, "ZDOTDIR": home.path], shellPath: "/bin/zsh")
    }

    #expect(failure?.message == "hook failed")
  }

  @Test func aChpwdHookWithAFailingCommandDoesNotEndTheHook() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    try "chpwd() { false; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let out = try await ShellCommand().runScript(
      "printf ran", in: home, environment: ["HOME": home.path, "ZDOTDIR": home.path],
      shellPath: "/bin/zsh")

    #expect(out == "ran")
  }

  @Test func aWorktreeThatCannotBeEnteredRunsNothing() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    let worktree = try Scratch.directory("worktree")
    let marker = home.appendingPathComponent("ran")
    try "rmdir \(AnyShellQuoting.quote(worktree.path))\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await ShellCommand().runScript(
        "touch \(AnyShellQuoting.quote(marker.path))", in: worktree,
        environment: ["HOME": home.path, "ZDOTDIR": home.path], shellPath: "/bin/zsh")
    }

    #expect(!FileManager.default.fileExists(atPath: marker.path))
  }

  @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh"])
  func aWorktreePathWithAnyPunctuationIsEnteredByEveryShell(shell: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    let worktree = try Scratch.directory(#"it's here!x a\b"#)
    defer { try? FileManager.default.removeItem(at: worktree) }
    for rc in [".zshrc", ".bash_profile", ".profile", ".tcshrc"] {
      try "cd /\n".write(to: home.appendingPathComponent(rc), atomically: true, encoding: .utf8)
    }

    let out = try await ShellCommand().runScript(
      "pwd", in: worktree, environment: ["HOME": home.path, "ZDOTDIR": home.path],
      shellPath: shell)

    #expect(out.trimmingCharacters(in: .newlines).hasSuffix(worktree.lastPathComponent))
  }

  @Test(arguments: ["/bin/bash", "/bin/sh", "/bin/ksh"])
  func aHookLeavesAHistoryFileTheEnvironmentNamesAlone(shell: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    let history = home.appendingPathComponent("zsh_history")
    let lines = (1...600).map { ": 1700000000:0;command \($0)\n" }.joined()
    try lines.write(to: history, atomically: true, encoding: .utf8)
    for rc in [".bash_profile", ".profile"] {
      try "HISTFILESIZE=10\n".write(
        to: home.appendingPathComponent(rc), atomically: true, encoding: .utf8)
    }

    _ = try await ShellCommand().runScript(
      "true", in: home, environment: ["HOME": home.path, "HISTFILE": history.path],
      shellPath: shell)

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  @Test func aChildThatReadsStdinGetsEOFNotTheApps() async throws {
    let out = try await ProcessRunner().run(
      URL(fileURLWithPath: "/bin/sh"), ["-c", "cat; printf done"],
      in: URL(fileURLWithPath: NSTemporaryDirectory()))
    #expect(out == "done")
  }

  @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh"])
  func aScriptStopsAtItsFirstFailingLineWhereTheShellCanBeTold(path: String) async throws {
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }
    let scratch = try Scratch.directory("script")
    defer { try? FileManager.default.removeItem(at: scratch) }
    func run(_ script: String) async throws -> String {
      try await ShellCommand().runScript(
        script, in: scratch, environment: shell.environment, shellPath: shell.path)
    }

    await #expect(throws: ProcessFailure.self) {
      try await run("echo one > first.txt\nfalse\necho two > second.txt")
    }
    #expect(
      FileManager.default.fileExists(atPath: scratch.appendingPathComponent("first.txt").path))
    #expect(
      !FileManager.default.fileExists(atPath: scratch.appendingPathComponent("second.txt").path),
      "the line after the failure ran")

    let out = try await run("printf a\nprintf b")
    #expect(out == "ab", "a sound script runs every line")
  }

  /// Under `-i` with no terminal the user's rc files write to stderr, and that noise was
  /// once the whole message of a failing hook that printed little itself.
  @Test(arguments: ["/bin/zsh", "/bin/bash"])
  func aFailingScriptsMessageIsItsOwnStderrNotTheRcFiles(path: String) async throws {
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }
    for file in [".zshrc", ".zprofile", ".zshenv", ".bashrc", ".bash_profile", ".profile"] {
      try "echo 'rc noise' >&2\n".write(
        to: shell.home.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    let cases: [(script: String, message: String)] = [
      ("echo 'the hook said so' >&2\nexit 3", "the hook said so"),
      ("exit 3", ""),
      ("echo hey\necho 'and then' >&2\nexit 3", "hey\nand then"),
      ("echo hey\nexit 3", "hey"),
    ]
    for (script, message) in cases {
      do {
        _ = try await ShellCommand().runScript(
          script, in: shell.home, environment: shell.environment, shellPath: shell.path)
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
      ShellCommand.scriptOutput(fromStderr: "noise\n\(marker)\nmine\nlogout\n") == "mine",
      "bash's parting word is not the hook's")
    #expect(ShellCommand.scriptOutput(fromStderr: "\(marker)\nlogout\n") == "", "silent hook")
    #expect(
      ShellCommand.scriptOutput(fromStderr: "\(marker)\nlogout early\n") == "logout early",
      "only the whole last line goes")
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

  @Test func theCshFamilyIsNotGivenTheLoginFlagItRefusesBesideC() async throws {
    #expect(ShellCommand.shell(named: "/bin/tcsh").arguments == ["-i", "-c"])
    #expect(ShellCommand.shell(named: "/bin/csh").arguments == ["-i", "-c"])
    guard FileManager.default.isExecutableFile(atPath: "/bin/tcsh") else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }

    let out = try await ShellCommand().runScript(
      "printf ok", in: home, environment: ["HOME": home.path], shellPath: "/bin/tcsh")

    #expect(out == "ok")
  }
}
