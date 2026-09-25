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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)

    let env = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
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
    #expect(reports.map(\.state) == [.running, .done, .running, .failed, .running, .done])
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
    let initFile = try ShellTab.bashInitFile(in: home)
    let env = ShellTab.environment(socket: listener.path, home: home)

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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)

    let env = ShellTab.environment(socket: listener.path, home: home, worktree: "/w/repo")
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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let env = ShellTab.environment(socket: listener.path, home: home)
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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let childPID = home.appendingPathComponent("child.pid")
    let env = ShellTab.environment(socket: home.appendingPathComponent("nowhere.sock"), home: home)
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
    let initFile = try ShellTab.bashInitFile(in: home, helper: helper)
    let childPID = home.appendingPathComponent("child.pid")
    let env = ShellTab.environment(socket: home.appendingPathComponent("nowhere.sock"), home: home)
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
    let initFile = try ShellTab.bashInitFile(in: home)
    let env = ShellTab.environment(socket: home.appendingPathComponent("nowhere.sock"), home: home)
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
    let initFile = try ShellTab.bashInitFile(in: home)
    let childPID = home.appendingPathComponent("child.pid")
    let env = ShellTab.environment(socket: listener.path, home: home)
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
}

/// The system's bash 3.2 and any newer one installed, whose `$!` and `wait` differ.
private let installedBashes = ["/bin/bash", "/opt/homebrew/bin/bash", "/usr/local/bin/bash"]
  .filter { FileManager.default.isExecutableFile(atPath: $0) }
