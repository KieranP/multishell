import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// What a real shell reports about the commands typed at it, and the agent it names.
extension ShellIntegrationScriptsTests {
  /// A helper whose relay writes down each line bash sends it. It can finish
  /// just after bash exits, so a test waits on the log rather than reads it.
  private func relayLogging(to log: URL, in scratch: URL) throws -> URL {
    try Scratch.script(
      "[ \"$1\" = relay ] || exit 0\nwhile IFS= read -r line; do printf '%s\\n' \"$line\" >> '\(log.path)'; done",
      at: scratch.appendingPathComponent("multishell"))
  }

  private static func lines(of log: URL) -> [String] {
    ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
  }

  /// An empty Enter runs nothing, so the arm lived on into the next
  /// PROMPT_COMMAND, where the user's own entry was reported as a command.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func anEmptyEnterUnderTheUsersPromptCommandStartsNoCommand() async throws {
    let bash = "/bin/bash"
    let scratch = try Scratch.directory("marks-helper")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\nPROMPT_COMMAND='history -a'\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "empty-enter"
    _ = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "\n\ntrue\n\nexit\n")

    try await waitUntil { Self.lines(of: log).count >= 3 }
    let lines = Self.lines(of: log).map { $0.split(separator: " ").first ?? "" }
    #expect(
      lines.filter { $0 == "command-started" }.count == 2, "one for `true` and one for `exit`")
    #expect(lines.filter { $0 == "command-finished" }.count == 1)
  }

  /// Typing an agent's name is how most agents start, and most have no
  /// hooks installed; the shell's own report is what marks the pane.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/bash")))
  func bashNamesAnAgentItStartsAndNothingElse() async throws {
    let bash = "/bin/bash"
    let scratch = try Scratch.directory("marks-command")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let codex = try Scratch.script("true", at: scratch.appendingPathComponent("codex"))
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "typed-agent"
    environment["PATH"] = scratch.path + ":" + (environment["PATH"] ?? "")
    _ = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "\(codex.path) --continue\nFOO=1 \(codex.path)\ntrue\nexit\n")

    try await waitUntil { Self.lines(of: log).count >= 7 }
    let lines = Self.lines(of: log).filter { $0.hasPrefix("command-started ") }
    #expect(
      lines.filter { $0.hasSuffix(" codex") }.count == 2,
      "the agent it ran, by name without its path or an assignment before it: \(lines)")
    #expect(
      lines.filter { $0.hasSuffix(" true") }.isEmpty,
      "and nothing of what else the user runs: \(lines)")
  }

  /// bash-preexec, which Atuin ships, sets its DEBUG trap from the prompt
  /// command it adds, after the init file has run.
  @Test(arguments: InstalledBashes.all)
  func aDebugTrapTheUsersPromptSetsLateStillFiresBesideTheReports(bash: String) async throws {
    let scratch = try Scratch.directory("late-debug")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      theirs() { echo "[theirs:$BASH_COMMAND]"; }
      PROMPT_COMMAND='[ -n "$installed" ] || { trap theirs DEBUG; installed=1; }'

      """)

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "late-debug"
    let output = try await interactiveShellOutput(
      bash, arguments: ["--init-file", files.bashInit.path, "-i"], environment: environment,
      input: "true\nexit\n")

    #expect(output.contains("[theirs:true]"), "\(output)")
    #expect(!output.contains("[theirs:trap -p PIPE"), "their trap never sees our reads: \(output)")
    try await waitUntil { Self.lines(of: log).contains { $0.hasPrefix("command-started") } }
    #expect(Self.lines(of: log).contains { $0.hasPrefix("command-started") })
  }

  /// zsh writes the report's JSON itself, so its own line is the only place
  /// the field can be malformed.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshWritesTheAgentIntoTheLineItSendsAndLeavesTheRestOut() throws {
    let lines = try zshPreexecLines([
      "_multishell_preexec 'codex --continue'",
      "_multishell_preexec '/usr/local/bin/opencode'",
      "_multishell_preexec 'ls -la ~/codex'",
    ])
    #expect(lines.count == 3, "one line per command: \(lines)")
    #expect(
      lines.allSatisfy { $0.contains("\"shell\":true") },
      "the shell says so on its own lines: \(lines)")
    #expect(lines[0].contains("\"command\":\"codex\"") == true, "\(lines)")
    #expect(
      lines[1].contains("\"command\":\"opencode\"") == true,
      "by its name, not its path: \(lines)")
    #expect(lines[2].contains("command") == false, "a plain command names nothing: \(lines)")
  }

  /// The lines the real `.zshrc` sends as it runs each line given, with the
  /// send replaced so nothing needs a socket.
  private func zshSentLines(_ calls: [String]) throws -> [String] {
    let zsh = "/bin/zsh"
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let script =
      ([
        "source \(files.zshDirectory.appendingPathComponent(".zshrc").path)",
        #"_multishell_send() { print -r -- "$1" }"#,
      ] + calls).joined(separator: "\n")
    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "zsh-typed"
    environment[SessionEnvironment.socketVariable] = "/tmp/nothing.sock"
    environment[SessionEnvironment.worktreeVariable] = "/w"
    let process = Process()
    process.executableURL = URL(fileURLWithPath: zsh)
    process.arguments = ["-c", script]
    process.environment = environment
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    return text.split(separator: "\n").map(String.init)
  }

  private func zshPreexecLines(_ calls: [String]) throws -> [String] {
    try zshSentLines(calls).filter { $0.contains("\"running\"") }
  }

  /// zsh hands preexec the line as typed and the line with its aliases expanded;
  /// bash's `BASH_COMMAND` is already expanded.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshReadsTheExpandedLineSoAnAliasedAgentIsStillTheAgent() throws {
    let lines = try zshPreexecLines([
      "_multishell_preexec 'cx' 'codex --continue'",
      "_multishell_preexec 'FOO=1 codex'",
      "_multishell_preexec 'command opencode'",
      "_multishell_preexec 'MY_CODEX=1 ls'",
    ])
    #expect(lines.count == 4, "one line per command: \(lines)")
    #expect(lines[0].contains("\"command\":\"codex\"") == true, "an alias: \(lines)")
    #expect(lines[1].contains("\"command\":\"codex\"") == true, "an assignment before it")
    #expect(lines[2].contains("\"command\":\"opencode\"") == true, "`command` before it")
    #expect(lines[3].contains("command") == false, "an assignment naming an agent is not one")
  }

  @Test func aUsersErrExitDoesNotEndTheShellAtItsFirstPrompt() async throws {
    let output = try await zshOutput(
      features: nil, input: "true\nprint -r survived\nexit\n", usersRC: "setopt err_exit\n")
    #expect(output.contains("survived"))
  }

  @Test func aReportTheHelperFailsToSendDoesNotEndAShellUnderErrExit() async throws {
    let output = try await zshOutput(
      features: nil, input: "setopt err_exit\ndisable zsocket\ntrue\nprint -r survived\nexit\n",
      helper: "/usr/bin/false")
    #expect(output.contains("survived"), "\(output)")
  }

  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshReportsIdleOnlyAsTheShellItselfExitsAndNotASubshell() throws {
    let lines = try zshSentLines(["(exit 4)", "print -r after"])
    #expect(lines.contains("after"), "\(lines)")
    #expect(lines.filter { $0.contains("\"state\":\"idle\"") }.count == 1, "\(lines)")
  }

  @Test func zshSendsAnIdleLineForItsSessionOnTheWayOut() async throws {
    let output = try await zshOutput(
      features: nil,
      input: #"_multishell_send() { print -r -- "line=$1" }; _multishell_zshexit"#,
      runsInputAsScript: true)
    #expect(output.contains(#"line={"v":1,"state":"idle","session":"zsh-output""#), "\(output)")
  }
}
