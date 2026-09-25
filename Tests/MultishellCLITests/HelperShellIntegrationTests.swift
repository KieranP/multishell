import Foundation
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellCore

/// The generated zsh and bash files driven by real shells, reporting
/// through the built helper to a socket standing in for the app.
@Suite(.serialized)
struct HelperShellIntegrationTests {
  @Test func zshIntegrationLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-inject-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    for (name, contents) in try ShellStateHooks.zshIntegrationFiles(
      helper: HelperBinary.require().path)
    {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: userZdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    var env = Scratch.shellEnvironment
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = session.uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    // Interactive zsh loads our .zshrc (which sources the user's and adds
    // the hooks); then drive the hooks around a good and a bad command.
    let script = """
      printf 'loaded=%s zdotdir=%s\\n' "$MULTISHELL_USER_RC_LOADED" "$ZDOTDIR"
      _multishell_preexec; true; _multishell_precmd
      _multishell_preexec; false; _multishell_precmd
      wait
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), ["-i", "-c", script], in: root, environment: env)

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .zshrc did not run: \(output.standardOutput)")
    #expect(
      output.standardOutput.contains("zdotdir=\(userZdotdir.path)"),
      "ZDOTDIR was not handed back to the user for nested shells: \(output.standardOutput)")

    try await waitUntil { recorder.received.count >= 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count == 2, "\(states)")
    #expect(states.contains(.done) && states.contains(.error), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
  }

  @Test func zshBuildsTheLineItSendsInAVariableRatherThanASubshell() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let root = try Scratch.directory("zsh-json")
    defer { Scratch.remove(root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    for (name, contents) in ShellStateHooks.zshIntegrationFiles(helper: "/bin/echo") {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    var env = Scratch.shellEnvironment
    env["HOME"] = root.path
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = root.path
    env["MULTISHELL_SESSION"] = "s"
    env["MULTISHELL_SOCKET"] = "/nonexistent.sock"

    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-i", "-c", #"_multishell_json idle ""; print -r -- "line=$_multishell_line""#],
      in: root, environment: env)

    #expect(output.standardOutput.contains(#"line={"v":1,"state":"idle","session":"s""#))
  }

  /// `%f` writes the locale's decimal separator, so a comma region sent
  /// `"duration":1,234` and the reader dropped the whole report.
  @Test func aCommaDecimalLocaleStillSendsAReportThatParses() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    // Skips where the locale is absent rather than failing on its absence.
    let comma = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"), ["-c", "printf '%.3f' 1.5"],
      in: URL(fileURLWithPath: "/tmp"), environment: ["LC_ALL": "de_DE.UTF-8"])
    guard comma.standardOutput.contains(",") else { return }

    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-locale-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    // Empty, so the chain does not reach the developer's own .zshrc, which
    // sets a locale of its own and would decide this test.
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    for (name, contents) in try ShellStateHooks.zshIntegrationFiles(
      helper: HelperBinary.require().path)
    {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    var env = Scratch.shellEnvironment
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    env["LC_ALL"] = "de_DE.UTF-8"
    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-i", "-c", "_multishell_preexec; true; _multishell_precmd; wait"], in: root,
      environment: env)

    try await waitUntil { recorder.received.count >= 2 }
    let finished = recorder.received.compactMap(SessionStateReport.parse).filter {
      $0.state == .done
    }
    #expect(finished.count == 1, "unparsed: \(recorder.received)")
    #expect(finished.first?.duration != nil, "the duration is what the separator broke")
  }

  /// The fraction was cut at a dot only. Apple's bash 3.2 has no
  /// `EPOCHREALTIME`, which is what lets a test set one by hand.
  @Test func aCommaDecimalLocaleStillGivesBashASaneDuration() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bashloc-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    let script = """
      EPOCHREALTIME='1700000000,250000'
      _multishell_command_started
      EPOCHREALTIME='1700000004,750000'
      _multishell_precmd
      wait
      """
    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/bash"), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    try await waitUntil { recorder.received.count >= 2 }
    let finished = recorder.received.compactMap(SessionStateReport.parse).filter {
      $0.state == .done
    }
    #expect(finished.count == 1, "got: \(recorder.received)")
    #expect(finished.first?.duration == 4, "the seconds between the two, not the whole string")
  }

  @Test func bashInitLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bash-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = session.uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    // An interactive bash reading our init in place of .bashrc, then the
    // hooks driven by hand around a passing and a failing command.
    let script = """
      printf 'loaded=%s\\n' "$MULTISHELL_USER_RC_LOADED"
      _multishell_command_started; true; _multishell_precmd
      _multishell_command_started; false; _multishell_precmd
      wait
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/bash"), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .bashrc did not load: \(output.standardOutput) \(output.standardError)")
    try await waitUntil { recorder.received.count >= 4 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count == 2, "\(states)")
    #expect(states.contains(.done) && states.contains(.error), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
    let durations = recorder.received.compactMap { SessionStateReport.parse($0)?.duration }
    #expect(durations.count == 2 && durations.allSatisfy { $0 >= 0 }, "\(durations)")
  }

  /// bash-preexec, which Atuin's bash install ships, replaces the DEBUG trap
  /// at the first prompt. Ours is taken back at each prompt and chains to it.
  @Test func bashKeepsItsDebugTrapAgainstOneInstalledAfterTheInit() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bashtrap-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    // Read from a pipe rather than `-c`, so PROMPT_COMMAND runs between the
    // late installer and the command, as it would at a real prompt.
    let script = home.appendingPathComponent("drive.sh")
    try """
    trap 'printf "theirs\\n"' DEBUG
    uname
    printf 'last\\n'
    wait
    """.write(to: script, atomically: true, encoding: .utf8)
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/sh"),
      [
        "-c",
        "exec /bin/bash --init-file \(PosixShellQuoting.quote(initFile.path)) -i < \(PosixShellQuoting.quote(script.path))",
      ],
      in: home, environment: env)

    // The line installing their trap is itself reported, ours still standing
    // when it runs; what the claim decides is whether `uname` is reported too.
    try await waitUntil { recorder.received.count >= 2 }
    let states = recorder.received.compactMap { SessionStateReport.parse($0)?.state }
    #expect(states.filter { $0 == .running }.count >= 2, "\(recorder.received)")
    // Theirs runs before each command, so what shows it is still being called
    // is a firing after the reclaim, not the one at the prompt it arrived at.
    let printed = output.standardOutput
    let afterOurs = printed.range(of: "Darwin").map { String(printed[$0.upperBound...]) } ?? ""
    #expect(afterOurs.contains("theirs"), "theirs stopped when ours came back: \(printed)")
    #expect(afterOurs.contains("last"), "and the script ran on")
  }

  /// `trap -p` prints the body quoted for re-input, so chaining to a trap `.bashrc` set
  /// first means unquoting it as the shell would; eval ran all of it as one word.
  @Test func bashChainsToATrapItsUserInstalledFirst() async throws {
    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bashprior-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    let marks = home.appendingPathComponent("theirs.txt")
    // Several words, as every real one is: bash-preexec's is
    // `__bp_preexec_invoke_exec "$_"`.
    try "trap 'printf x >> \(marks.path)' DEBUG\n".write(
      to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    let script = home.appendingPathComponent("drive.sh")
    try "uname\n".write(to: script, atomically: true, encoding: .utf8)
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/sh"),
      [
        "-c",
        "exec /bin/bash --init-file \(PosixShellQuoting.quote(initFile.path)) -i "
          + "< \(PosixShellQuoting.quote(script.path))",
      ], in: home, environment: env)

    let theirs = (try? String(contentsOf: marks, encoding: .utf8)) ?? ""
    #expect(!theirs.isEmpty, "the user's own trap never ran: \(output.standardError)")
    // Run as one word, bash names the whole body in the complaint, and does
    // it once per command for the life of the session.
    #expect(
      !output.standardError.contains(marks.path),
      "their trap was run as one word: \(output.standardError)")
  }

  /// bash does not restore `$?` between PROMPT_COMMAND entries, so a prompt
  /// that shows the last exit code reads whatever ours left behind.
  @Test func bashPrecmdHandsOnTheStatusItWasGiven() async throws {
    let home = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-bashstatus-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    let script = """
      _multishell_command_started
      false
      _multishell_precmd
      printf 'ran=%s\\n' "$?"
      true
      _multishell_precmd
      printf 'quiet=%s\\n' "$?"
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/bash"), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    #expect(output.standardOutput.contains("ran=1"), "\(output.standardOutput)")
    #expect(output.standardOutput.contains("quiet=0"), "\(output.standardOutput)")
  }

  /// A user whose ~/.zshenv sets ZDOTDIR keeps their config: the chain
  /// follows the directory their .zshenv leaves, not $HOME.
  @Test func zshIntegrationFollowsAZdotdirSetByTheUsersZshenv() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-relocate-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    for dir in [integration, relocated] {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    for (name, contents) in try ShellStateHooks.zshIntegrationFiles(
      helper: HelperBinary.require().path)
    {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["ZDOTDIR"] = integration.path
    env.removeValue(forKey: "MULTISHELL_USER_ZDOTDIR")
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      [
        "-i", "-c",
        "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\"; _multishell_preexec",
      ],
      in: root, environment: env)

    let fields = output.standardOutput.split(separator: "|", omittingEmptySubsequences: false)
    #expect(
      fields.first == "relocated", "the relocated .zshrc did not run: \(output.standardOutput)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output.standardOutput)")
    try await waitUntil { !recorder.received.isEmpty }
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.state == .running)
  }

  /// A user whose ~/.zprofile sets ZDOTDIR, which only a login shell reads,
  /// keeps their config too: the profile chain captures what it left.
  @Test func zshIntegrationFollowsAZdotdirSetByTheUsersZprofile() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-profile-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    for dir in [integration, relocated] {
      try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    for (name, contents) in try ShellStateHooks.zshIntegrationFiles(
      helper: HelperBinary.require().path)
    {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zprofile"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    // The runner merges this over the process's own, which from a Multishell
    // tab names a session and a socket; blank, the hooks do nothing.
    let env = [
      "HOME": home.path, "ZDOTDIR": integration.path, "MULTISHELL_SESSION": "",
      "MULTISHELL_SOCKET": "", "MULTISHELL_USER_ZDOTDIR": "",
    ]
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-l", "-i", "-c", "printf '%s|%s' \"$MULTISHELL_USER_RC_LOADED\" \"$ZDOTDIR\""],
      in: root, environment: env)

    let fields = output.standardOutput.split(separator: "|", omittingEmptySubsequences: false)
    #expect(
      fields.first == "relocated", "the relocated .zshrc did not run: \(output.standardOutput)")
    #expect(
      fields.count == 2 && fields[1] == relocated.path,
      "ZDOTDIR handed back to the relocated dir: \(output.standardOutput)")
  }

  /// git refuses a control character in a branch name, but a parent directory
  /// may carry one, and the zsh line escaped only backslash and quote.
  @Test func aWorktreePathHoldingAControlCharacterStillReportsFromZsh() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let path = listener.path
    let recorder = listener.recorder

    let root = URL(fileURLWithPath: "/tmp")
      .appendingPathComponent("ms-cntrl-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let integration = root.appendingPathComponent("integration", isDirectory: true)
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: integration, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    for (name, contents) in try ShellStateHooks.zshIntegrationFiles(
      helper: HelperBinary.require().path)
    {
      try contents.write(
        to: integration.appendingPathComponent(name), atomically: true, encoding: .utf8)
    }

    let worktree = "/w/re\tpo\nsit\"or\\y"
    var env = Scratch.shellEnvironment
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
    env["MULTISHELL_SOCKET"] = path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = worktree
    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/zsh"),
      ["-i", "-c", "_multishell_preexec; true; _multishell_precmd; wait"], in: root,
      environment: env)

    try await waitUntil { recorder.received.count >= 2 }
    let received = recorder.received
    let reports = received.compactMap(SessionStateReport.parse)
    #expect(reports.count == received.count, "unparsed: \(received)")
    #expect(Set(reports.map(\.state)).isSuperset(of: [.running, .done]), "\(reports.map(\.state))")
    #expect(reports.allSatisfy { $0.cwd == worktree }, "\(reports.map(\.cwd))")
  }

  /// The helper behind a script noting its pid, parent and first argument, so a test
  /// can count what a bash tab starts and find the relay; the sandbox refuses `ps`.
  private func countingHelper(in home: URL) throws -> (helper: URL, log: URL) {
    let log = home.appendingPathComponent("spawns.log")
    let helper = try Scratch.script(
      "echo \"$PPID\" >> \(PosixShellQuoting.quote(log.path + ".parents"))\n"
        + "echo \"$$ $1\" >> \(PosixShellQuoting.quote(log.path))\n"
        + "exec \(PosixShellQuoting.quote(try HelperBinary.require().path)) \"$@\"",
      at: home.appendingPathComponent("multishell"))
    return (helper, log)
  }

  private func spawns(_ log: URL) -> [(pid: String, command: String)] {
    ((try? String(contentsOf: log, encoding: .utf8)) ?? "").split(whereSeparator: \.isNewline)
      .map { line in
        let fields = line.split(separator: " ", maxSplits: 1).map(String.init)
        return (fields[0], fields.count > 1 ? fields[1] : "")
      }
  }

  @Test func bashReportsEveryCommandThroughOneRelayRatherThanAHelperEach() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelay")
    defer { Scratch.remove(home) }
    let (helper, log) = try countingHelper(in: home)
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = listener.path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    let script = """
      _multishell_command_started "claude --resume"; true; _multishell_precmd
      _multishell_command_started "ls"; false; _multishell_precmd
      _multishell_command_started "make"; true; _multishell_precmd
      """
    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: "/bin/bash"), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    try await waitUntil { recorder.received.count >= 6 }
    let reports = recorder.received.compactMap(SessionStateReport.parse)
    #expect(reports.map(\.state) == [.running, .done, .running, .error, .running, .done])
    #expect(reports.first?.command == "claude")
    #expect(reports.first?.pid != nil)
    #expect(spawns(log).map(\.command) == ["relay"])
  }

  /// `printf` stood in by a function, so each report says the subshell depth it was written at.
  @Test(arguments: installedBashes)
  func bashWritesEachReportToTheRelayWithoutASubshell(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelayfork")
    defer { Scratch.remove(home) }
    let depths = home.appendingPathComponent("depths.log")
    try """
    printf() {
      case "$2" in command-*) echo "$BASH_SUBSHELL ${2%% *}" >> \(PosixShellQuoting.quote(depths.path)) ;; esac
      builtin printf "$@"
    }

    """.write(to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = listener.path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString

    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash),
      [
        "--init-file", initFile.path, "-i", "-c",
        #"_multishell_command_started "ls"; true; _multishell_precmd"#,
      ],
      in: home, environment: env, timeout: .seconds(10))

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      try String(contentsOf: depths, encoding: .utf8) == "0 command-started\n0 command-finished\n")
  }

  /// The relay's parent is killed too, or it reads the pipe once the relay fails
  /// and the shell never writes to a pipe with no reader.
  @Test(arguments: installedBashes)
  func aBashWhoseRelayHasGoneLivesOnAndReportsThroughTheHelper(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelaygone")
    defer { Scratch.remove(home) }
    let (helper, log) = try countingHelper(in: home)
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)

    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = listener.path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    env["MULTISHELL_WORKTREE"] = "/w/repo"
    let script = """
      while [ ! -s \(PosixShellQuoting.quote(log.path)) ]; do sleep 0.05; done
      kill -KILL "$(head -n 1 \(PosixShellQuoting.quote(log.path + ".parents")))"
      kill -KILL "$(cut -d' ' -f1 \(PosixShellQuoting.quote(log.path)))"
      sleep 0.3
      _multishell_command_started "ls"; true; _multishell_precmd
      printf 'alive\\n'
      printf 'still-heard\\n' >&2
      """
    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env)

    #expect(output.standardOutput.contains("alive"), "\(output.standardError)")
    #expect(output.standardError.contains("still-heard"), "the shell's own stderr went too")
    try await waitUntil { recorder.received.count >= 2 }
    let states = recorder.received.compactMap(SessionStateReport.parse).map(\.state)
    #expect(states == [.running, .done])
    #expect(spawns(log).map(\.command) == ["relay", "command-started", "command-finished"])
  }

  /// The stand-in relay is a helper from before `relay` existed, held until the
  /// reports are in the pipe so its usage error comes after them.
  @Test(arguments: installedBashes)
  func aRelayThatEndsWithoutReadingLosesNoReport(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelayrefused")
    defer { Scratch.remove(home) }
    let written = home.appendingPathComponent("written")
    let helper = try Scratch.script(
      """
      if [ "$1" = relay ]; then
        while [ ! -e \(PosixShellQuoting.quote(written.path)) ]; do sleep 0.05; done
        exit 2
      fi
      exec \(PosixShellQuoting.quote(try HelperBinary.require().path)) "$@"
      """,
      at: home.appendingPathComponent("multishell"))
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = listener.path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let script = """
      _multishell_command_started "ls"; true; _multishell_precmd
      : > \(PosixShellQuoting.quote(written.path))
      """

    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env, timeout: .seconds(10))

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      recorder.received.compactMap(SessionStateReport.parse).map(\.state) == [.running, .done])
  }

  @Test(arguments: installedBashes)
  func aBashRelayEndsWithItsShellThoughABackgroundChildHoldsThePipe(bash: String) async throws {
    let home = try Scratch.directory("bashrelaychild")
    defer { Scratch.remove(home) }
    let (helper, log) = try countingHelper(in: home)
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    let childPID = home.appendingPathComponent("child.pid")
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let script = """
      while [ ! -s \(PosixShellQuoting.quote(log.path)) ]; do sleep 0.05; done
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(PosixShellQuoting.quote(childPID.path))
      """

    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env, timeout: .seconds(10))
    let child = try #require(
      Int32(String(contentsOf: childPID, encoding: .utf8).trimmingCharacters(in: .newlines)))
    defer { kill(child, SIGKILL) }
    let relay = try #require(spawns(log).first.flatMap { Int32($0.pid) })

    #expect(kill(child, 0) == 0, "the child that holds the pipe is still running")
    try await waitUntil { kill(relay, 0) != 0 }
    #expect(kill(relay, 0) != 0, "the relay outlived its shell")
  }

  @Test(arguments: installedBashes)
  func aRefusedRelaysLoopEndsWithItsShellThoughAChildHoldsThePipe(bash: String) async throws {
    let home = try Scratch.directory("bashloopchild")
    defer { Scratch.remove(home) }
    let parents = home.appendingPathComponent("parents.log")
    let helper = try Scratch.script(
      """
      if [ "$1" = relay ]; then echo "$PPID" >> \(PosixShellQuoting.quote(parents.path)); exit 2; fi
      exec \(PosixShellQuoting.quote(try HelperBinary.require().path)) "$@"
      """,
      at: home.appendingPathComponent("multishell"))
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: helper.path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    let childPID = home.appendingPathComponent("child.pid")
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let script = """
      while [ ! -s \(PosixShellQuoting.quote(parents.path)) ]; do sleep 0.05; done
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(PosixShellQuoting.quote(childPID.path))
      """

    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env, timeout: .seconds(10))
    let child = try #require(
      Int32(String(contentsOf: childPID, encoding: .utf8).trimmingCharacters(in: .newlines)))
    defer { kill(child, SIGKILL) }
    let loop = try #require(
      Int32(String(contentsOf: parents, encoding: .utf8).trimmingCharacters(in: .newlines)))

    #expect(kill(child, 0) == 0, "the child that holds the pipe is still running")
    try await waitUntil { kill(loop, 0) != 0 }
    #expect(kill(loop, 0) != 0, "the read loop outlived its shell")
  }

  @Test(arguments: installedBashes)
  func aPipeTrapSetAfterTheInitSurvivesTheNextReport(bash: String) async throws {
    let home = try Scratch.directory("bashpipetrap")
    defer { Scratch.remove(home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let script = """
      _multishell_command_started "trap"
      trap 'echo mine' PIPE
      _multishell_precmd
      _multishell_command_started "true"; true
      trap -p PIPE
      """

    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env, timeout: .seconds(10))

    #expect(
      output.standardOutput.contains("trap -- 'echo mine' SIGPIPE"),
      "\(output.standardOutput) \(output.standardError)")
  }

  @Test(arguments: installedBashes)
  func aBashRelayStillSendsWhatItsShellWroteJustBeforeExiting(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelaydrain")
    defer { Scratch.remove(home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    let childPID = home.appendingPathComponent("child.pid")
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = listener.path.path
    env["MULTISHELL_SESSION"] = UUID().uuidString
    let script = """
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(PosixShellQuoting.quote(childPID.path))
      _multishell_command_started "ls"; true; _multishell_precmd
      """

    _ = try await ProcessRunner().capture(
      URL(fileURLWithPath: bash), ["--init-file", initFile.path, "-i", "-c", script],
      in: home, environment: env, timeout: .seconds(10))
    let child = try #require(
      Int32(String(contentsOf: childPID, encoding: .utf8).trimmingCharacters(in: .newlines)))
    defer { kill(child, SIGKILL) }

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      recorder.received.compactMap(SessionStateReport.parse).map(\.state) == [.running, .done])
  }

  /// bash 4.4 and later point $! at a process substitution, and a bare `wait` waits on it.
  /// Only a bash that new shows it; the one macOS ships is 3.2, so this skips without one.
  @Test func aBareWaitInABashTabReturns() async throws {
    let newer = ["/opt/homebrew/bin/bash", "/usr/local/bin/bash"].first {
      FileManager.default.isExecutableFile(atPath: $0)
    }
    guard let newer else { return }
    let home = try Scratch.directory("bashwait")
    defer { Scratch.remove(home) }
    let initFile = home.appendingPathComponent("init.bash")
    try ShellStateHooks.bashInitFile(helper: HelperBinary.require().path)
      .write(to: initFile, atomically: true, encoding: .utf8)
    var env = Scratch.shellEnvironment
    env["HOME"] = home.path
    env["MULTISHELL_SOCKET"] = home.appendingPathComponent("nowhere.sock").path
    env["MULTISHELL_SESSION"] = UUID().uuidString

    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: newer),
      ["--init-file", initFile.path, "-i", "-c", "wait; printf 'waited\\n'"],
      in: home, environment: env, timeout: .seconds(10))

    #expect(output.standardOutput.contains("waited"), "\(output.standardError)")
  }
}

/// The system's bash 3.2 and any newer one installed, whose `$!` and `wait` differ.
private let installedBashes = ["/bin/bash", "/opt/homebrew/bin/bash", "/usr/local/bin/bash"]
  .filter { FileManager.default.isExecutableFile(atPath: $0) }
