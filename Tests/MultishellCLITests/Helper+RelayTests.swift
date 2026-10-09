import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

/// A bash tab's one resident relay, driven by real bash through the built
/// helper, and what the shell does when the relay is gone or refused.
@Suite(.serialized)
struct HelperRelayTests {
  /// The helper behind a script noting its pid, parent and first argument, so a test
  /// can count what a bash tab starts and find the relay; the sandbox refuses `ps`.
  private func countingHelper(in home: URL) throws -> (helper: URL, log: URL) {
    let log = home.appendingPathComponent("spawns.log")
    let helper = try Scratch.script(
      "echo \"$PPID\" >> \(AnyShellQuoting.quote(log.path + ".parents"))\n"
        + "echo \"$$ $1\" >> \(AnyShellQuoting.quote(log.path))\n"
        + "exec \(AnyShellQuoting.quote(try HelperBinary.require().path)) \"$@\"",
      at: home.appendingPathComponent("multishell"),
    )
    return (helper, log)
  }

  /// The helper behind a script that runs `relayBody` in place of `relay`.
  private func helper(in home: URL, relayingAs relayBody: String) throws -> URL {
    try Scratch.script(
      """
      if [ "$1" = relay ]; then
      \(relayBody)
      fi
      exec \(AnyShellQuoting.quote(try HelperBinary.require().path)) "$@"
      """,
      at: home.appendingPathComponent("multishell"),
    )
  }

  private func pid(writtenTo file: URL) throws -> Int32 {
    try #require(
      Int32(String(contentsOf: file, encoding: .utf8).trimmingCharacters(in: .newlines))
    )
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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)

    let environment = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
    let script = """
      _multishell_command_started "claude --resume"; true; _multishell_precmd
      _multishell_command_started "ls"; false; _multishell_precmd
      _multishell_command_started "make"; true; _multishell_precmd
      """
    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
    )

    try await waitUntil { recorder.received.count >= 6 }
    let reports = recorder.received.compactMap(SessionStateReport.parse)
    #expect(reports.map(\.state) == [.running, .done, .running, .failed, .running, .done])
    #expect(reports.first?.command == "claude")
    #expect(reports.first?.pid != nil)
    #expect(spawns(log).map(\.command) == ["relay"])
  }

  /// `printf` stood in by a function, so each report says the subshell depth it was written at.
  @Test(arguments: InstalledBashes.all)
  func bashWritesEachReportToTheRelayWithoutASubshell(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelayfork")
    defer { Scratch.remove(home) }
    let depths = home.appendingPathComponent("depths.log")
    try """
    printf() {
      case "$2" in command-*) echo "$BASH_SUBSHELL ${2%% *}" >> \(AnyShellQuoting.quote(depths.path)) ;; esac
      builtin printf "$@"
    }

    """.write(to: home.appendingPathComponent(".bashrc"), atomically: true, encoding: .utf8)
    let initFile = try ShellTab.bashInitFile(in: home)
    let environment = ShellTab.environment(socket: listener.path, home: home)

    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: #"_multishell_command_started "ls"; true; _multishell_precmd"#,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      try String(contentsOf: depths, encoding: .utf8) == "0 command-started\n0 command-finished\n"
    )
  }

  /// The relay's parent is killed too, or it reads the pipe once the relay fails
  /// and the shell never writes to a pipe with no reader.
  @Test(arguments: InstalledBashes.all)
  func aBashWhoseRelayHasGoneLivesOnAndReportsThroughTheHelper(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelaygone")
    defer { Scratch.remove(home) }
    let (helper, log) = try countingHelper(in: home)
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)

    let environment = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
    let script = """
      while [ ! -s \(AnyShellQuoting.quote(log.path)) ]; do sleep 0.05; done
      kill -KILL "$(head -n 1 \(AnyShellQuoting.quote(log.path + ".parents")))"
      kill -KILL "$(cut -d' ' -f1 \(AnyShellQuoting.quote(log.path)))"
      sleep 0.3
      _multishell_command_started "ls"; true; _multishell_precmd
      printf 'alive\\n'
      printf 'still-heard\\n' >&2
      """
    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
    )

    #expect(output.standardOutput.contains("alive"), "\(output.standardError)")
    #expect(output.standardError.contains("still-heard"), "the shell's own stderr went too")
    try await waitUntil { recorder.received.count >= 2 }
    let states = recorder.received.compactMap(SessionStateReport.parse).map(\.state)
    #expect(states == [.running, .done])
    #expect(spawns(log).map(\.command) == ["relay", "command-started", "command-finished"])
  }

  /// The stand-in relay is a helper from before `relay` existed, held until the
  /// reports are in the pipe so its usage error comes after them.
  @Test(arguments: InstalledBashes.all)
  func aRelayThatEndsWithoutReadingLosesNoReport(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelayrefused")
    defer { Scratch.remove(home) }
    let written = home.appendingPathComponent("written")
    let helper = try helper(
      in: home,
      relayingAs: """
        while [ ! -e \(AnyShellQuoting.quote(written.path)) ]; do sleep 0.05; done
        exit 2
        """,
    )
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let environment = ShellTab.environment(socket: listener.path, home: home)
    let script = """
      _multishell_command_started "ls"; true; _multishell_precmd
      : > \(AnyShellQuoting.quote(written.path))
      """

    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      recorder.received.compactMap(SessionStateReport.parse).map(\.state) == [.running, .done]
    )
  }

  @Test(arguments: InstalledBashes.all)
  func aBashRelayEndsWithItsShellThoughABackgroundChildHoldsThePipe(bash: String) async throws {
    let home = try Scratch.directory("bashrelaychild")
    defer { Scratch.remove(home) }
    let (helper, log) = try countingHelper(in: home)
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let childPID = home.appendingPathComponent("child.pid")
    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
    )
    let script = """
      while [ ! -s \(AnyShellQuoting.quote(log.path)) ]; do sleep 0.05; done
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(AnyShellQuoting.quote(childPID.path))
      """

    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )
    let child = try pid(writtenTo: childPID)
    defer { kill(child, SIGKILL) }
    let relay = try #require(spawns(log).first.flatMap { Int32($0.pid) })

    #expect(kill(child, 0) == 0, "the child that holds the pipe is still running")
    try await waitUntil { kill(relay, 0) != 0 }
    #expect(kill(relay, 0) != 0, "the relay outlived its shell")
  }

  @Test(arguments: InstalledBashes.all)
  func aRefusedRelaysLoopEndsWithItsShellThoughAChildHoldsThePipe(bash: String) async throws {
    let home = try Scratch.directory("bashloopchild")
    defer { Scratch.remove(home) }
    let parents = home.appendingPathComponent("parents.log")
    let helper = try helper(
      in: home,
      relayingAs: "echo \"$PPID\" >> \(AnyShellQuoting.quote(parents.path)); exit 2",
    )
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let childPID = home.appendingPathComponent("child.pid")
    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
    )
    let script = """
      while [ ! -s \(AnyShellQuoting.quote(parents.path)) ]; do sleep 0.05; done
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(AnyShellQuoting.quote(childPID.path))
      """

    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )
    let child = try pid(writtenTo: childPID)
    defer { kill(child, SIGKILL) }
    let loop = try pid(writtenTo: parents)

    #expect(kill(child, 0) == 0, "the child that holds the pipe is still running")
    try await waitUntil { kill(loop, 0) != 0 }
    #expect(kill(loop, 0) != 0, "the read loop outlived its shell")
  }

  @Test(arguments: InstalledBashes.all)
  func aPipeTrapSetAfterTheInitSurvivesTheNextReport(bash: String) async throws {
    let home = try Scratch.directory("bashpipetrap")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
    )
    let script = """
      _multishell_command_started "trap"
      trap 'echo mine' PIPE
      _multishell_precmd
      _multishell_command_started "true"; true
      trap -p PIPE
      """

    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )

    #expect(
      output.standardOutput.contains("trap -- 'echo mine' SIGPIPE"),
      "\(output.standardOutput) \(output.standardError)",
    )
  }

  @Test(arguments: InstalledBashes.all)
  func aBashFromFiveThreeOnReadsThePipeTrapInTheShell(bash: String) async throws {
    let home = try Scratch.directory("bashpipetrapread")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let environment = ShellTab.environment(
      socket: home.appendingPathComponent("nowhere.sock"),
      home: home,
    )
    let script =
      #"echo "version=$(( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] ))"; "#
      + #"echo "read=$_multishell_read_pipe_trap""#

    let output = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )

    let lines = output.standardOutput.split(whereSeparator: \.isNewline)
    let version = try #require(
      lines.first { $0.hasPrefix("version=") }.flatMap { Int($0.dropFirst("version=".count)) }
    )
    let read = try #require(lines.first { $0.hasPrefix("read=") })
    #expect(read.contains("${ trap -p PIPE; }") == (version >= 503), "\(bash): \(read)")
  }

  @Test(arguments: InstalledBashes.all)
  func aBashRelayStillSendsWhatItsShellWroteJustBeforeExiting(bash: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder
    let home = try Scratch.directory("bashrelaydrain")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.bashInitFile(in: home)
    let childPID = home.appendingPathComponent("child.pid")
    let environment = ShellTab.environment(socket: listener.path, home: home)
    let script = """
      sleep 60 </dev/null >/dev/null 2>&1 &
      echo $! > \(AnyShellQuoting.quote(childPID.path))
      _multishell_command_started "ls"; true; _multishell_precmd
      """

    _ = try await ShellTab.runBash(
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
      bash: bash,
      timeout: .seconds(10),
    )
    let child = try pid(writtenTo: childPID)
    defer { kill(child, SIGKILL) }

    try await waitUntil { recorder.received.count >= 2 }
    #expect(
      recorder.received.compactMap(SessionStateReport.parse).map(\.state) == [.running, .done]
    )
  }
}
