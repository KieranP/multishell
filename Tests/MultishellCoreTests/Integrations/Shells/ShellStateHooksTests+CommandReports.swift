import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// What a real shell reports about the commands typed at it, and the agent it names.
extension ShellStateHooksTests {
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
  @Test func anEmptyEnterUnderTheUsersPromptCommandStartsNoCommand() async throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let scratch = try Scratch.directory("marks-helper")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\nPROMPT_COMMAND='history -a'\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionKey] = "empty-enter"
    _ = try await interactiveShell(
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
  @Test func bashNamesAnAgentItStartsAndNothingElse() async throws {
    let bash = "/bin/bash"
    guard FileManager.default.isExecutableFile(atPath: bash) else { return }
    let scratch = try Scratch.directory("marks-command")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let codex = try Scratch.script("true", at: scratch.appendingPathComponent("codex"))
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionKey] = "typed-agent"
    environment["PATH"] = scratch.path + ":" + (environment["PATH"] ?? "")
    _ = try await interactiveShell(
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

  /// zsh writes the report's JSON itself, so its own line is the only place
  /// the field can be malformed.
  @Test func zshWritesTheAgentIntoTheLineItSendsAndLeavesTheRestOut() throws {
    guard
      let lines = try zshPreexecLines([
        "_multishell_preexec 'codex --continue'",
        "_multishell_preexec '/usr/local/bin/opencode'",
        "_multishell_preexec 'ls -la ~/codex'",
      ])
    else { return }
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

  /// The `running` lines the real `.zshrc` sends for each `_multishell_preexec`
  /// call given, with the send replaced so nothing needs a socket.
  private func zshPreexecLines(_ calls: [String]) throws -> [String]? {
    let zsh = "/bin/zsh"
    guard FileManager.default.isExecutableFile(atPath: zsh) else { return nil }
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let script =
      ([
        "source \(files.zshDirectory.appendingPathComponent(".zshrc").path)",
        #"_multishell_send() { print -r -- "$1" }"#,
      ] + calls).joined(separator: "\n")
    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionKey] = "zsh-typed"
    environment[SessionEnvironment.socketKey] = "/tmp/nothing.sock"
    environment[SessionEnvironment.worktreeKey] = "/w"
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
    // The shell exits at the end of the script, which reports idle too.
    return text.split(separator: "\n").filter { $0.contains("\"running\"") }.map(String.init)
  }

  /// zsh hands preexec the line as typed and the line with its aliases expanded;
  /// bash's `BASH_COMMAND` is already expanded.
  @Test func zshReadsTheExpandedLineSoAnAliasedAgentIsStillTheAgent() throws {
    guard
      let lines = try zshPreexecLines([
        "_multishell_preexec 'cx' 'codex --continue'",
        "_multishell_preexec 'FOO=1 codex'",
        "_multishell_preexec 'command opencode'",
        "_multishell_preexec 'MY_CODEX=1 ls'",
      ])
    else { return }
    #expect(lines.count == 4, "one line per command: \(lines)")
    #expect(lines[0].contains("\"command\":\"codex\"") == true, "an alias: \(lines)")
    #expect(lines[1].contains("\"command\":\"codex\"") == true, "an assignment before it")
    #expect(lines[2].contains("\"command\":\"opencode\"") == true, "`command` before it")
    #expect(lines[3].contains("command") == false, "an assignment naming an agent is not one")
  }
}
