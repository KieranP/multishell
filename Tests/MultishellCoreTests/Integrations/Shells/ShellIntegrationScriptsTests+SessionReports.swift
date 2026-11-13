import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// What a real shell reports about the commands typed at it, and the agent it names.
extension ShellIntegrationScriptsTests {
  private static func lines(of log: URL) -> [String] {
    ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
  }

  /// A helper whose relay writes down each line bash sends it. It can finish
  /// just after bash exits, so a test waits on the log rather than reads it.
  private func relayLogging(to log: URL, in scratch: URL) throws -> URL {
    try Scratch.script(
      "[ \"$1\" = relay ] || exit 0\nwhile IFS= read -r line; do printf '%s\\n' \"$line\" >> '\(log.path)'; done",
      at: scratch.appendingPathComponent("multishell"),
    )
  }

  /// bash applies errexit to a PROMPT_COMMAND entry, so a status handed back
  /// by returning it ended a `set -e` shell at the prompt after any failure.
  @Test(arguments: InstalledBashes.all)
  func aUsersErrExitDoesNotEndTheShellAfterAFailure(bash: String) async throws {
    let scratch = try Scratch.directory("bash-errexit")
    defer { Scratch.remove(scratch) }
    let helper = try relayLogging(to: scratch.appendingPathComponent("log"), in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      "set -e\nPS1='[$?]> '\nPROMPT_COMMAND='seen=$?'\n",
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "errexit"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "false && true\necho \"survived $seen\"\nexit\n",
    )

    #expect(output.contains("survived 1"))
  }

  /// The shared-history recipe prepends to PROMPT_COMMAND, so sourcing the
  /// .bashrc again put the user's entry before ours, which then read its 0.
  @Test(arguments: InstalledBashes.all)
  func aBashrcSourcedAgainLeavesFailuresReportedAsFailures(bash: String) async throws {
    let scratch = try Scratch.directory("bash-resourced")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      "PS1='> '\nmine() { :; }\nexport PROMPT_COMMAND=\"mine; ${PROMPT_COMMAND-}\"\n",
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "bash-resourced"
    _ = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "false\nsource ~/.bashrc\nfalse\nfalse\nexit\n",
    )

    try await waitUntil { Self.lines(of: log).count { $0.hasPrefix("command-finished") } >= 4 }
    let statuses = Self.lines(of: log).filter { $0.hasPrefix("command-finished") }
      .map { $0.split(separator: " ")[1] }
    #expect(statuses == ["1", "0", "1", "1"])
  }

  /// Before 5.1 bash runs element 0 alone, so putting ours back as an element of
  /// its own moved every other entry, the arm included, where nothing ran it.
  @Test(arguments: InstalledBashes.all)
  func anArrayBashrcSourcedAgainKeepsEveryHookRunning(bash: String) async throws {
    let scratch = try Scratch.directory("bash-array-resourced")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      mine() { :; }
      if [ -z "${loaded-}" ]; then loaded=1; PROMPT_COMMAND=(mine mine)
      else PROMPT_COMMAND="mine; ${PROMPT_COMMAND}"; fi

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "bash-array-resourced"
    _ = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "false\nsource ~/.bashrc\nfalse\nfalse\nexit\n",
    )

    try await waitUntil { Self.lines(of: log).count { $0.hasPrefix("command-finished") } >= 4 }
    let statuses = Self.lines(of: log).filter { $0.hasPrefix("command-finished") }
      .map { $0.split(separator: " ")[1] }
    #expect(statuses == ["1", "0", "1", "1"])
  }

  /// bash-preexec puts its entry first at the first prompt to read PIPESTATUS;
  /// ours moved in front of it, and on 5.x its BP_PIPESTATUS read ours.
  @Test(arguments: InstalledBashes.all)
  func bashPreexecsFirstEntryKeepsItsPlace(bash: String) async throws {
    let scratch = try Scratch.directory("bash-preexec-first")
    defer { Scratch.remove(scratch) }
    let helper = try relayLogging(to: scratch.appendingPathComponent("log"), in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      __bp_precmd_invoke_cmd() { :; }
      __bp_install() {
        PROMPT_COMMAND="__bp_precmd_invoke_cmd"$'\\n'"${PROMPT_COMMAND//__bp_install/:}"
      }
      PROMPT_COMMAND=__bp_install

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "bash-preexec-first"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "true\ntrue\necho \"first=[${PROMPT_COMMAND%%$'\\n'*}]\"\nexit\n",
    )

    #expect(output.contains("first=[__bp_precmd_invoke_cmd]"), "\(output)")
  }

  /// The bash `exec bash` put in the pane read only `.bashrc`, so the pane's last
  /// report was `running`, for good.
  @Test(arguments: InstalledBashes.all)
  func aBashThatExecsBashKeepsTheReports(bash: String) async throws {
    let scratch = try Scratch.directory("bash-exec")
    defer { Scratch.remove(scratch) }
    let helper = try relayLogging(to: scratch.appendingPathComponent("log"), in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "bash-exec"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input:
        "exec \(bash)\ndeclare -F _multishell_precmd >/dev/null && echo HOOKED-$((1+1))\nexit\n",
    )

    #expect(output.contains("HOOKED-2"), "\(output)")
  }

  /// The re-exec ran the line as typed, unexpanded, and a failed exec inside the
  /// DEBUG trap ends even an interactive bash; the pane closed.
  @Test(arguments: InstalledBashes.all)
  func anExecOfABashThatIsNotThereLeavesTheShellRunning(bash: String) async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    try files.writeHomeFile(".bashrc", "PS1='> '\n")

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "bash-exec-missing"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "exec /nowhere/bash\necho SURVIVED-$((1+1))\nexit\n",
    )

    #expect(output.contains("SURVIVED-2"), "\(output)")
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
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "\n\ntrue\n\nexit\n",
    )

    try await waitUntil { Self.lines(of: log).count >= 3 }
    let lines = Self.lines(of: log).map { $0.split(separator: " ").first ?? "" }
    #expect(
      lines.filter { $0 == "command-started" }.count == 2,
      "one for `true` and one for `exit`",
    )
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
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: """
        \(codex.path) --continue
        FOO=1 \(codex.path)
        FOO="a b" \(codex.path)
        env NAME='a  b' \(codex.path)
        true
        exit

        """,
    )

    try await waitUntil { Self.lines(of: log).count >= 11 }
    let lines = Self.lines(of: log).filter { $0.hasPrefix("command-started ") }
    #expect(
      lines.filter { $0.hasSuffix(" codex") }.count == 4,
      "the agent it ran, by name without its path or an assignment, quoted or not, before it: \(lines)",
    )
    #expect(
      !lines.contains { $0.hasSuffix(" true") },
      "and nothing of what else the user runs: \(lines)",
    )
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

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "late-debug"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "true\nexit\n",
    )

    #expect(output.contains("[theirs:true]"), "\(output)")
    #expect(!output.contains("[theirs:trap -p PIPE"), "their trap never sees our reads: \(output)")
    try await waitUntil { Self.lines(of: log).contains { $0.hasPrefix("command-started") } }
    #expect(Self.lines(of: log).contains { $0.hasPrefix("command-started") })
  }

  /// bash-preexec appends its entry to PROMPT_COMMAND at the first prompt, after our
  /// arm, and running it took the arm meant for the agent typed next.
  @Test(arguments: InstalledBashes.all)
  func aPromptEntryBashPreexecAddsLateLeavesTheNextCommandReported(bash: String) async throws {
    let scratch = try Scratch.directory("late-entry")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let codex = try Scratch.script("true", at: scratch.appendingPathComponent("codex"))
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      __bp_interactive_mode() { :; }
      __bp_install() { PROMPT_COMMAND+=$'\\n__bp_interactive_mode'; installed=1; }
      PROMPT_COMMAND='[ -n "$installed" ] || __bp_install'

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "late-entry"
    environment["PATH"] = scratch.path + ":" + (environment["PATH"] ?? "")
    _ = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "true\n\(codex.path)\nexit\n",
    )

    try await waitUntil {
      Self.lines(of: log).filter { $0.hasPrefix("command-started") }.count >= 3
    }
    let started = Self.lines(of: log).filter { $0.hasPrefix("command-started") }
    #expect(started.contains { $0.hasSuffix(" codex") }, "\(started)")
    #expect(started.count == 3, "true, the agent and exit: \(started)")
  }

  /// Theirs is run from inside ours, whose argument it must not see as its own.
  @Test(arguments: InstalledBashes.all)
  func theUsersDebugTrapSeesNoArgumentsOfOurs(bash: String) async throws {
    let scratch = try Scratch.directory("trap-arguments")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      theirs() { case "$BASH_COMMAND" in true) echo "[args:$#]" ;; esac; }
      PROMPT_COMMAND='[ -n "$installed" ] || { trap '"'"'theirs "$@"'"'"' DEBUG; installed=1; }'

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "trap-arguments"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "true\nexit\n",
    )

    #expect(output.contains("[args:0]"), "\(output)")
  }

  /// Under `extdebug` a DEBUG trap's non-zero status skips the command, which
  /// bash-preexec documents as a feature; ours returned its own status over theirs.
  @Test(arguments: InstalledBashes.all)
  func theUsersDebugTrapStillSkipsACommandUnderExtdebug(bash: String) async throws {
    let scratch = try Scratch.directory("trap-skip")
    defer { Scratch.remove(scratch) }
    let helper = try relayLogging(to: scratch.appendingPathComponent("log"), in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      shopt -s extdebug
      guard() { case "$BASH_COMMAND" in *BLOCKED*) return 1 ;; esac; }
      trap guard DEBUG

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "trap-skip"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "echo RAN-$((1+1))\necho BLOCKED-$((1+1))\nexit\n",
    )

    #expect(output.contains("RAN-2"), "\(output)")
    #expect(!output.contains("BLOCKED-2"), "\(output)")
  }

  /// bash sets `$_` after a trap to the trap command's last word, so a bare
  /// `_multishell_debug` broke `mkdir x && cd $_`, and bash-preexec's own `"$_"`.
  @Test(arguments: InstalledBashes.all)
  func theLastArgumentSurvivesTheReportsForTheUserAndTheirOwnTrap(bash: String) async throws {
    let scratch = try Scratch.directory("last-argument")
    defer { Scratch.remove(scratch) }
    let log = scratch.appendingPathComponent("log")
    let helper = try relayLogging(to: log, in: scratch)
    let files = try GeneratedIntegration(helper: helper.path)
    defer { files.tearDown() }
    try files.writeHomeFile(
      ".bashrc",
      """
      PS1='> '
      theirs() { case "$BASH_COMMAND" in true) echo "[theirs:$1]" ;; esac; }
      PROMPT_COMMAND='[ -n "$installed" ] || { trap '"'"'theirs "$_"'"'"' DEBUG; installed=1; }'

      """,
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "last-argument"
    let output = try await interactiveShellOutput(
      bash,
      arguments: ["--init-file", files.bashInit.path, "-i"],
      environment: environment,
      input: "echo foo bar\necho \"last=$_\"\necho one two\ntrue\nexit\n",
    )

    #expect(output.contains("last=bar"), "\(output)")
    #expect(output.contains("[theirs:two]"), "\(output)")
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
      "the shell says so on its own lines: \(lines)",
    )
    #expect(lines[0].contains("\"command\":\"codex\"") == true, "\(lines)")
    #expect(
      lines[1].contains("\"command\":\"opencode\"") == true,
      "by its name, not its path: \(lines)",
    )
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

  /// Our hooks read `precmd_functions`, which a pane outside Ghostty may not
  /// have yet; under the user's `no_unset` that read ended the file.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshUnderNoUnsetStillInstallsTheReports() async throws {
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let script = """
      setopt no_unset
      source \(files.zshDirectory.appendingPathComponent(".zshrc").path)
      print -r -- "hooks=${precmd_functions[*]-}"
      """
    var environment = files.zshEnvironment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "zsh-no-unset"
    environment[SessionEnvironment.socketVariable] = "/tmp/nothing.sock"
    environment[SessionEnvironment.worktreeVariable] = "/w"

    let output = try await Detached.output(
      of: "/bin/zsh",
      ["-c", script],
      environment: environment,
    )

    #expect(output.contains("hooks=_multishell_precmd"), "\(output)")
  }

  /// `zsocket` hands back its descriptor in `REPLY`, so a send that connects
  /// left the user's `read` answer as a number. zsh listens itself here.
  @Test(.enabled(if: InstalledShells.isInstalled("/bin/zsh")))
  func zshReportsLeaveTheUsersReplyAlone() async throws {
    let scratch = try Scratch.directory("zsh-reply")
    defer { Scratch.remove(scratch) }
    let socket = scratch.appendingPathComponent("s").path
    let files = try GeneratedIntegration(helper: "/bin/echo")
    defer { files.tearDown() }
    let script = """
      zmodload zsh/net/socket
      zsocket -l \(socket)
      source \(files.zshDirectory.appendingPathComponent(".zshrc").path)
      REPLY=kept
      _multishell_preexec true
      _multishell_precmd
      print -r -- "REPLY=[$REPLY]"
      """
    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "zsh-reply"
    environment[SessionEnvironment.socketVariable] = socket
    environment[SessionEnvironment.worktreeVariable] = "/w"

    let output = try await Detached.output(
      of: "/bin/zsh",
      ["-c", script],
      environment: environment,
    )

    #expect(output.contains("REPLY=[kept]"), "\(output)")
  }

  /// A slow prompt hook, vcs_info or a git theme, was billed to every command
  /// and held its Done until the prompt was drawn.
  @Test func zshReportsACommandsEndBeforeTheUsersPromptHooksRun() async throws {
    let output = try await zshOutput(
      features: nil,
      input: "_multishell_send() { print -r -- \"sent $1\" }\ntrue\nexit\n",
      usersRC: "theirs() { print -r -- theirs-ran }\nprecmd_functions+=(theirs)\n",
    )

    let started = try #require(output.range(of: "\"state\":\"running\""))
    let rest = output[started.upperBound...]
    let done = try #require(rest.range(of: "\"state\":\"done\""), "\(output)")
    let theirs = try #require(rest.range(of: "theirs-ran"), "\(output)")
    #expect(done.lowerBound < theirs.lowerBound, "\(output)")
  }

  /// `exec zsh` and omz's reload put a new zsh in the pane, which read only the
  /// user's files: the pane's last report was `running`, for good.
  @Test func aZshThatExecsZshKeepsTheReports() async throws {
    let output = try await zshOutput(
      features: nil,
      input: """
        exec zsh -i
        print -r -- "hooks=[${precmd_functions[*]}] zdotdir=[${ZDOTDIR-}]"
        exit

        """,
    )
    #expect(output.contains("_multishell_precmd"), "\(output)")
    #expect(output.contains("zdotdir=[]"), "\(output)")
  }

  /// A zsh that reads no startup file, or runs a command, never reaches ours to
  /// hand ZDOTDIR back, and its own children would load the reports.
  @Test(arguments: ["-f", "-c true"])
  func aZshExecThatReadsNoRcKeepsTheUsersZdotdir(flags: String) async throws {
    let output = try await zshOutput(
      features: nil,
      input: """
        exec zsh \(flags == "-f" ? "-f" : "-c 'print -r -- \"zdotdir=[${ZDOTDIR-}]\"'")
        print -r -- "zdotdir=[${ZDOTDIR-}]"
        exit

        """,
    )
    #expect(output.contains("zdotdir=[]"), "\(output)")
  }

  @Test func aReloadThatDidNotReplaceTheShellHandsZdotdirBack() async throws {
    let output = try await zshOutput(
      features: nil,
      input: "omz reload\nprint -r -- \"zdotdir=[${ZDOTDIR-}]\"\nexit\n",
    )
    #expect(output.contains("zdotdir=[]"), "\(output)")
  }

  @Test func aUsersErrExitDoesNotEndTheShellAtItsFirstPrompt() async throws {
    let output = try await zshOutput(
      features: nil,
      input: "true\nprint -r survived\nexit\n",
      usersRC: "setopt err_exit\n",
    )
    #expect(output.contains("survived"))
  }

  @Test func aReportTheHelperFailsToSendDoesNotEndAShellUnderErrExit() async throws {
    let output = try await zshOutput(
      features: nil,
      input: "setopt err_exit\ndisable zsocket\ntrue\nprint -r survived\nexit\n",
      helper: "/usr/bin/false",
    )
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
      runsInputAsScript: true,
    )
    #expect(output.contains(#"line={"v":1,"state":"idle","session":"zsh-output""#), "\(output)")
  }

  /// A fish run with a helper, under the home and spaced path it is written
  /// as, that writes down what it is sent.
  private func fishRun(
    _ fish: String,
    input: String,
  ) async throws -> (output: String, sent: [String]) {
    let files = try GeneratedIntegration(helper: "$HOME/Application Support/multishell")
    defer { files.tearDown() }
    let log = files.root.appendingPathComponent("log")
    let directory = files.home.appendingPathComponent("Application Support")
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Scratch.script(
      "printf '%s\\n' \"$*\" >> '\(log.path)'",
      at: directory.appendingPathComponent("multishell"),
    )

    var environment = files.environment(termProgram: nil)
    environment[SessionEnvironment.sessionVariable] = "fish-home"
    let launch = ShellLaunch.fishInitArguments(forShell: fish, fishInit: files.fishInit)
    let output = try await interactiveShellOutput(
      fish,
      arguments: Array(launch.dropFirst()) + ["-i"],
      environment: environment,
      input: input,
    )
    return (output, Self.lines(of: log))
  }

  /// fish fires both events for a line holding only a comment, and its postexec
  /// carried the last command's status, so a comment after `false` read as failed.
  @Test(arguments: InstalledShells.fishes)
  func fishReportsNothingForALineHoldingOnlyAComment(fish: String) async throws {
    let sent = try await fishRun(
      fish,
      input: "false; emit fish_preexec '# a note'; emit fish_postexec '# a note'\nexit\n",
    ).sent

    #expect(!sent.contains { $0.hasPrefix("command-") }, "\(sent)")
  }

  @Test(arguments: InstalledShells.fishes)
  func fishFindsTheHelperUnderTheHomeAndSpacedPathItIsWrittenAs(fish: String) async throws {
    let sent = try await fishRun(fish, input: "emit fish_preexec claude\nexit\n").sent

    #expect(sent.first?.hasPrefix("command-started --pid ") == true)
    #expect(sent.first?.hasSuffix(" --command claude") == true)
  }

  /// fish hands preexec the whole line, a backslash and newline included,
  /// where Enter continued it.
  @Test(arguments: InstalledShells.fishes)
  func fishNamesAnAgentTypedOnTheLineAfterAContinuedPrefix(fish: String) async throws {
    let sent = try await fishRun(
      fish,
      input: "emit fish_preexec 'env FOO=1 \\\nclaude --resume'\nexit\n",
    ).sent

    #expect(sent.first?.hasSuffix(" --command claude") == true, "\(sent)")
  }

  @Test(arguments: InstalledShells.fishes)
  func fishPrintsNoErrorForAHelperRemovedAfterItStarted(fish: String) async throws {
    let run = try await fishRun(
      fish,
      input: """
        rm "$HOME/Application Support/multishell"
        emit fish_preexec true
        emit fish_postexec true
        exit

        """,
    )

    #expect(!run.output.contains("Unknown command"), "\(run.output)")
  }
}
