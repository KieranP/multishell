import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

extension ShellIntegrationThroughHelperTests {
  /// The fraction was cut at a dot only. Apple's bash 3.2 has no
  /// `EPOCHREALTIME`, which is what lets a test set one by hand.
  @Test func aCommaDecimalLocaleStillGivesBashASaneDuration() async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let home = try Scratch.directory("bashloc")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let environment = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
    let script = """
      EPOCHREALTIME='1700000000,250000'
      _multishell_command_started
      EPOCHREALTIME='1700000004,750000'
      _multishell_precmd
      wait
      """
    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
    )

    try await waitUntil { recorder.received.count >= 2 }
    let finished = recorder.received.compactMap(SessionStateReport.parse).filter { report in
      report.state == .done
    }
    #expect(finished.count == 1, "got: \(recorder.received)")
    #expect(finished.first?.duration == 4, "the seconds between the two, not the whole string")
  }

  @Test(arguments: InstalledBashes.all)
  func bashInitLoadsUserConfigAndReportsThroughInjectedHooks(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let home = try Scratch.directory("bash")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    try "export MULTISHELL_USER_RC_LOADED=yes\n".write(
      to: home.appendingPathComponent(".bashrc"),
      atomically: true,
      encoding: .utf8,
    )

    let session = UUID()
    let environment = ShellTab.environment(
      socket: listener.path,
      session: session,
      home: home,
      worktree: "/w/repo",
    )
    let script = """
      printf 'loaded=%s\\n' "$MULTISHELL_USER_RC_LOADED"
      _multishell_command_started; true; _multishell_precmd
      _multishell_command_started; false; _multishell_precmd
      wait
      """
    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
    )

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's .bashrc did not load: \(output.standardOutput) \(output.standardError)",
    )
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
  @Test(arguments: InstalledBashes.all)
  func bashKeepsItsDebugTrapAgainstOneInstalledAfterTheInit(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let home = try Scratch.directory("bashtrap")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let environment = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
    // Read from a pipe rather than `-c`, so PROMPT_COMMAND runs between the
    // late installer and the command, as it would at a real prompt.
    let script = home.appendingPathComponent("drive.sh")
    try """
    trap 'printf "theirs\\n"' DEBUG
    uname
    printf 'last\\n'
    wait
    """.write(to: script, atomically: true, encoding: .utf8)
    let output = try await ShellTab.runBash(
      bash,
      initFile: initFile,
      feeding: script,
      in: home,
      environment: environment,
    )

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
  @Test(arguments: InstalledBashes.all)
  func bashChainsToATrapItsUserInstalledFirst(bash: String) async throws {
    let home = try Scratch.directory("bashprior")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let marks = home.appendingPathComponent("theirs.txt")
    // Several words, as every real one is: bash-preexec's is
    // `__bp_preexec_invoke_exec "$_"`.
    try "trap 'printf x >> \(marks.path)' DEBUG\n".write(
      to: home.appendingPathComponent(".bashrc"),
      atomically: true,
      encoding: .utf8,
    )

    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
      worktree: "/w/repo",
    )
    let script = home.appendingPathComponent("drive.sh")
    try "uname\n".write(to: script, atomically: true, encoding: .utf8)
    let output = try await ShellTab.runBash(
      bash,
      initFile: initFile,
      feeding: script,
      in: home,
      environment: environment,
    )

    let theirs = (try? String(contentsOf: marks, encoding: .utf8)) ?? ""
    #expect(!theirs.isEmpty, "the user's own trap never ran: \(output.standardError)")
    // Run as one word, bash names the whole body in the complaint, and does
    // it once per command for the life of the session.
    #expect(
      !output.standardError.contains(marks.path),
      "their trap was run as one word: \(output.standardError)",
    )
  }

  /// bash does not restore `$?` between PROMPT_COMMAND entries, so a prompt
  /// that shows the last exit code reads whatever ours left behind.
  @Test(arguments: InstalledBashes.all)
  func bashPrecmdHandsOnTheStatusItWasGiven(bash: String) async throws {
    let home = try Scratch.directory("bashstatus")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)

    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
      worktree: "/w/repo",
    )
    let script = """
      _multishell_command_started
      false
      _multishell_precmd
      printf 'ran=%s\\n' "$?"
      true
      _multishell_precmd
      printf 'quiet=%s\\n' "$?"
      """
    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
    )

    #expect(output.standardOutput.contains("ran=1"), "\(output.standardOutput)")
    #expect(output.standardOutput.contains("quiet=0"), "\(output.standardOutput)")
  }

  /// bash 4.4 and later point $! at a process substitution, and a bare `wait` waits on it.
  /// Only a bash that new shows it; the one macOS ships is 3.2, so this skips without one.
  @Test(.enabled(if: InstalledBashes.newer != nil)) func aBareWaitInABashTabReturns() async throws {
    let newer = try #require(InstalledBashes.newer)
    let home = try Scratch.directory("bashwait")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
    )

    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: "wait; printf 'waited\\n'",
      in: home,
      environment: environment,
      bash: newer,
      timeout: .seconds(10),
    )

    #expect(output.standardOutput.contains("waited"), "\(output.standardError)")
  }
}
