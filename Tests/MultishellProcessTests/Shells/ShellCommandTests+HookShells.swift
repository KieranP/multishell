import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

extension ShellCommandTests {
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

    let out = try await ShellCommand.runScript(
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

    let out = try await ShellCommand.runScript(
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
      try await ShellCommand.runScript(
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

    let out = try await ShellCommand.runScript(
      "printf ran", in: home, environment: ["HOME": home.path, "ZDOTDIR": home.path],
      shellPath: "/bin/zsh")

    #expect(out == "ran")
  }

  @Test(arguments: [("/bin/zsh", ".zshrc"), ("/bin/tcsh", ".tcshrc")])
  func aWorktreeThatCannotBeEnteredRunsNothing(shell: String, rcFile: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: shell) else { return }
    let home = try Scratch.directory("home")
    defer { try? FileManager.default.removeItem(at: home) }
    let worktree = try Scratch.directory("worktree")
    let marker = home.appendingPathComponent("ran")
    try "rmdir \(AnyShellQuoting.quote(worktree.path))\n".write(
      to: home.appendingPathComponent(rcFile), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await ShellCommand.runScript(
        "touch \(AnyShellQuoting.quote(marker.path))", in: worktree,
        environment: ["HOME": home.path, "ZDOTDIR": home.path], shellPath: shell)
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

    let out = try await ShellCommand.runScript(
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

    _ = try await ShellCommand.runScript(
      "true", in: home, environment: ["HOME": home.path, "HISTFILE": history.path],
      shellPath: shell)

    #expect(try String(contentsOf: history, encoding: .utf8) == lines)
  }

  @Test(arguments: ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh"] + fishPaths)
  func aScriptStopsAtItsFirstFailingLineWhateverTheLoginShell(path: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: path) else { return }
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }
    let scratch = try Scratch.directory("script")
    defer { try? FileManager.default.removeItem(at: scratch) }
    func run(_ script: String) async throws -> String {
      try await ShellCommand.runScript(
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

  static let fishPaths = ["/opt/homebrew/bin/fish", "/usr/local/bin/fish"]

  @Test(arguments: ["/bin/zsh", "/bin/tcsh"] + fishPaths)
  func aScriptIsReadAsShWhateverTheLoginShell(path: String) async throws {
    guard FileManager.default.isExecutableFile(atPath: path) else { return }
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }

    let out = try await ShellCommand.runScript(
      "for f in *.nomatch; do :; done; for f in a b; do printf %s \"$f\"; done", in: shell.home,
      environment: shell.environment, shellPath: shell.path)

    #expect(out == "ab")
  }

  @Test func aVariableATcshRcFileSetsReachesTheScript() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/tcsh") else { return }
    let shell = try ScratchShell("/bin/tcsh")
    defer { shell.tearDown() }
    try "setenv MULTISHELL_RC tcshrc\n".write(
      to: shell.home.appendingPathComponent(".tcshrc"), atomically: true, encoding: .utf8)

    let out = try await ShellCommand.runScript(
      "printf '%s' \"$MULTISHELL_RC\"", in: shell.home, environment: shell.environment,
      shellPath: shell.path)

    #expect(out == "tcshrc")
  }

  @Test func theScriptsTextIsNotLeftInItsChildrensEnvironment() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }

    let out = try await ShellCommand.runScript(
      "env | grep -c MULTISHELL_SCRIPT || true", in: shell.home,
      environment: shell.environment, shellPath: shell.path)

    #expect(out.trimmingCharacters(in: .whitespacesAndNewlines) == "0")
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
        _ = try await ShellCommand.runScript(
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

  @Test func theMarkerSplitsStderr() {
    let marker = ShellCommand.outputMarker
    #expect(ShellCommand.scriptOutput(fromStderr: "noise\n\(marker)\nmine\n") == "mine")
    #expect(ShellCommand.scriptOutput(fromStderr: "noise\n\(marker)\n") == "")
    #expect(ShellCommand.scriptOutput(fromStderr: "no marker here") == "no marker here")
  }

}
