import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// The generated zsh and bash files driven by real shells, reporting
/// through the built helper to a socket standing in for the app.
@Suite(.serialized)
struct HelperShellIntegrationTests {
  @Test func zshIntegrationLoadsUserConfigAndReportsThroughInjectedHooks() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let root = try Scratch.directory("inject")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: userZdotdir.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    var env = ShellTab.environment(socket: listener.path, session: session, worktree: "/w/repo")
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
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
    #expect(states.contains(.done) && states.contains(.failed), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
  }

  @Test func zshBuildsTheLineItSendsInAVariableRatherThanASubshell() async throws {
    guard FileManager.default.isExecutableFile(atPath: "/bin/zsh") else { return }
    let root = try Scratch.directory("zsh-json")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root, helper: "/bin/echo")
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
    let recorder = listener.recorder

    let root = try Scratch.directory("locale")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    // Empty, so the chain does not reach the developer's own .zshrc, which
    // sets a locale of its own and would decide this test.
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)

    var env = ShellTab.environment(socket: listener.path, worktree: "/w/repo")
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
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
    let recorder = listener.recorder

    let home = try Scratch.directory("bashloc")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let env = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
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
    let recorder = listener.recorder

    let home = try Scratch.directory("bash")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)

    let session = UUID()
    let env = ShellTab.environment(
      socket: listener.path, session: session, home: home, worktree: "/w/repo")
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
    #expect(states.contains(.done) && states.contains(.failed), "\(states)")
    #expect(SessionStateReport.parse(recorder.received.first ?? "")?.sessionID == session)
    let durations = recorder.received.compactMap { SessionStateReport.parse($0)?.duration }
    #expect(durations.count == 2 && durations.allSatisfy { $0 >= 0 }, "\(durations)")
  }

  /// bash-preexec, which Atuin's bash install ships, replaces the DEBUG trap
  /// at the first prompt. Ours is taken back at each prompt and chains to it.
  @Test func bashKeepsItsDebugTrapAgainstOneInstalledAfterTheInit() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let home = try Scratch.directory("bashtrap")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let env = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
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
    let home = try Scratch.directory("bashprior")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let marks = home.appendingPathComponent("theirs.txt")
    // Several words, as every real one is: bash-preexec's is
    // `__bp_preexec_invoke_exec "$_"`.
    try "trap 'printf x >> \(marks.path)' DEBUG\n".write(
      to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)

    let env = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"), home: home, worktree: "/w/repo")
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
    let home = try Scratch.directory("bashstatus")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let env = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"), home: home, worktree: "/w/repo")
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
    let recorder = listener.recorder

    let root = try Scratch.directory("relocate")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: relocated, withIntermediateDirectories: true)
    try "export ZDOTDIR=\"$HOME/.config/zsh\"\n".write(
      to: home.appendingPathComponent(".zshenv"), atomically: true, encoding: .utf8)
    try "export MULTISHELL_USER_RC_LOADED=relocated\n".write(
      to: relocated.appendingPathComponent(".zshrc"), atomically: true, encoding: .utf8)

    var env = ShellTab.environment(socket: listener.path, home: home)
    env["ZDOTDIR"] = integration.path
    env.removeValue(forKey: "MULTISHELL_USER_ZDOTDIR")
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
    let root = try Scratch.directory("profile")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let home = root.appendingPathComponent("home", isDirectory: true)
    let relocated = home.appendingPathComponent(".config/zsh", isDirectory: true)
    try FileManager.default.createDirectory(at: relocated, withIntermediateDirectories: true)
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
    let recorder = listener.recorder

    let root = try Scratch.directory("cntrl")
    defer { Scratch.remove(root) }
    let integration = try ShellTab.zshIntegrationDirectory(in: root)
    let userZdotdir = root.appendingPathComponent("user", isDirectory: true)
    try FileManager.default.createDirectory(at: userZdotdir, withIntermediateDirectories: true)

    let worktree = "/w/re\tpo\nsit\"or\\y"
    var env = ShellTab.environment(socket: listener.path, worktree: worktree)
    env["ZDOTDIR"] = integration.path
    env["MULTISHELL_USER_ZDOTDIR"] = userZdotdir.path
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

  /// bash 4.4 and later point $! at a process substitution, and a bare `wait` waits on it.
  /// Only a bash that new shows it; the one macOS ships is 3.2, so this skips without one.
  @Test func aBareWaitInABashTabReturns() async throws {
    let newer = ["/opt/homebrew/bin/bash", "/usr/local/bin/bash"].first {
      FileManager.default.isExecutableFile(atPath: $0)
    }
    guard let newer else { return }
    let home = try Scratch.directory("bashwait")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let env = ShellTab.environment(socket: home.appendingPathComponent("nowhere.sock"), home: home)

    let output = try await ProcessRunner().capture(
      URL(fileURLWithPath: newer),
      ["--init-file", initFile.path, "-i", "-c", "wait; printf 'waited\\n'"],
      in: home, environment: env, timeout: .seconds(10))

    #expect(output.standardOutput.contains("waited"), "\(output.standardError)")
  }
}
