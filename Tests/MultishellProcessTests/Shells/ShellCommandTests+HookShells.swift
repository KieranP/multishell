import Foundation
import TestScratch
import Testing

@testable import MultishellProcess

extension ShellCommandTests {
  /// Hooks must see the PATH a terminal sees: a login, interactive shell
  /// reads its rc files, each of which exports a marker under this home.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aHookRunsInAnInteractiveLoginShellThatReadsItsRcFiles() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let home = shell.home
    for (file, marker) in [
      (".zshrc", "zshrc"), (".zprofile", "zprofile"), (".bashrc", "bashrc"),
      (".bash_profile", "bash_profile"), (".profile", "profile"),
    ] {
      try "export MULTISHELL_RC=\(marker)\n".write(
        to: home.appendingPathComponent(file), atomically: true, encoding: .utf8)
    }

    let out = try await ShellCommand.runScript(
      "printf '%s' \"$MULTISHELL_RC\"", in: home,
      environment: shell.environment, shellPath: shell.path)

    #expect(out == "zshrc", ".zprofile then .zshrc, as a login interactive zsh reads them")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aHookRunsInItsDirectoryWhereverTheRcFilesLeftTheShell() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let home = shell.home
    let worktree = try Scratch.directory("it's here")
    defer { Scratch.remove(worktree) }
    try "cd /\nchpwd() { echo noise; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let out = try await ShellCommand.runScript(
      "pwd -P", in: worktree, environment: shell.environment,
      shellPath: shell.path)

    let expected = try #require(Scratch.physicalPath(of: worktree))
    #expect(out.trimmingCharacters(in: .newlines) == expected)
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aChpwdHooksStderrIsNotTakenForTheFailingHooksMessage() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let home = shell.home
    try "chpwd() { echo 'direnv: loading .envrc' >&2; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let failure = await #expect(throws: ProcessFailure.self) {
      try await ShellCommand.runScript(
        "echo 'hook failed' >&2\nexit 3", in: home,
        environment: shell.environment, shellPath: shell.path)
    }

    #expect(failure?.message == "hook failed")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func aChpwdHookWithAFailingCommandDoesNotEndTheHook() async throws {
    let shell = try ScratchShell()
    defer { shell.tearDown() }
    let home = shell.home
    try "chpwd() { false; }\n".write(
      to: home.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let out = try await ShellCommand.runScript(
      "printf ran", in: home, environment: shell.environment,
      shellPath: shell.path)

    #expect(out == "ran")
  }

  @Test(arguments: InstalledShells.only([("/bin/zsh", ".zshrc"), ("/bin/tcsh", ".tcshrc")]))
  func aWorktreeThatCannotBeEnteredRunsNothing(shell: String, rcFile: String) async throws {
    let scratchShell = try ScratchShell(shell)
    defer { scratchShell.tearDown() }
    let home = scratchShell.home
    let worktree = try Scratch.directory("worktree")
    let marker = home.appendingPathComponent("ran")
    try "rmdir \(AnyShellQuoting.quote(worktree.path))\n".write(
      to: home.appendingPathComponent(rcFile), atomically: true, encoding: .utf8)

    await #expect(throws: ProcessFailure.self) {
      try await ShellCommand.runScript(
        "touch \(AnyShellQuoting.quote(marker.path))", in: worktree,
        environment: scratchShell.environment, shellPath: shell)
    }

    #expect(!FileManager.default.fileExists(atPath: marker.path))
  }

  @Test(arguments: InstalledShells.only(["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh"]))
  func aWorktreePathWithAnyPunctuationIsEnteredByEveryShell(shell: String) async throws {
    let scratchShell = try ScratchShell(shell)
    defer { scratchShell.tearDown() }
    let home = scratchShell.home
    let worktree = try Scratch.directory(#"it's here!x a\b"#)
    defer { Scratch.remove(worktree) }
    for rc in [".zshrc", ".bash_profile", ".profile", ".tcshrc"] {
      try "cd /\n".write(to: home.appendingPathComponent(rc), atomically: true, encoding: .utf8)
    }

    let out = try await ShellCommand.runScript(
      "pwd", in: worktree, environment: scratchShell.environment,
      shellPath: shell)

    #expect(out.trimmingCharacters(in: .newlines).hasSuffix(worktree.lastPathComponent))
  }

  @Test(arguments: InstalledShells.only(["/bin/bash", "/bin/sh", "/bin/ksh"]))
  func aHookLeavesAHistoryFileTheEnvironmentNamesAlone(shell: String) async throws {
    let scratchShell = try ScratchShell(shell)
    defer { scratchShell.tearDown() }
    let home = scratchShell.home
    let history = home.appendingPathComponent("zsh_history")
    let lines = LongHistory.lines
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

  @Test(
    arguments: InstalledShells.only(
      ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/tcsh"] + InstalledShells.fishCandidates))
  func aScriptStopsAtItsFirstFailingLineWhateverTheLoginShell(path: String) async throws {
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }
    let scriptDirectory = try Scratch.directory("script")
    defer { Scratch.remove(scriptDirectory) }
    func run(_ script: String) async throws -> String {
      try await ShellCommand.runScript(
        script, in: scriptDirectory, environment: shell.environment, shellPath: shell.path)
    }

    await #expect(throws: ProcessFailure.self) {
      try await run("echo one > first.txt\nfalse\necho two > second.txt")
    }
    #expect(
      FileManager.default.fileExists(
        atPath: scriptDirectory.appendingPathComponent("first.txt").path))
    #expect(
      !FileManager.default.fileExists(
        atPath: scriptDirectory.appendingPathComponent("second.txt").path),
      "the line after the failure ran")

    let out = try await run("printf a\nprintf b")
    #expect(out == "ab", "a sound script runs every line")
  }

  @Test(
    arguments: InstalledShells.only(["/bin/zsh", "/bin/tcsh"] + InstalledShells.fishCandidates))
  func aScriptIsReadAsShWhateverTheLoginShell(path: String) async throws {
    let shell = try ScratchShell(path)
    defer { shell.tearDown() }

    let out = try await ShellCommand.runScript(
      "for f in *.nomatch; do :; done; for f in a b; do printf %s \"$f\"; done", in: shell.home,
      environment: shell.environment, shellPath: shell.path)

    #expect(out == "ab")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/tcsh")))
  func aVariableATcshRcFileSetsReachesTheScript() async throws {
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
    let marker = ShellCommand.stderrStartMarker
    #expect(
      ShellCommand.failureMessage(standardOutput: "hey\n", standardError: "noise\n\(marker)\nbad\n")
        == "hey\nbad")
    #expect(
      ShellCommand.failureMessage(standardOutput: "", standardError: "\(marker)\n") == "",
      "silent")
    #expect(ShellCommand.failureMessage(standardOutput: "  hey  ", standardError: "") == "hey")
  }

  @Test func aScriptsStderrIsWhatFollowsTheMarkerOrAllOfItWithoutOne() {
    let marker = ShellCommand.stderrStartMarker
    #expect(ShellCommand.stderrAfterMarker("noise\n\(marker)\nmine\n") == "mine")
    #expect(ShellCommand.stderrAfterMarker("noise\n\(marker)\n") == "")
    #expect(ShellCommand.stderrAfterMarker("no marker here") == "no marker here")
  }

}
