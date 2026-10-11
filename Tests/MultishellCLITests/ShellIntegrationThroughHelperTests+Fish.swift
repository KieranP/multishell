import Foundation
import TestScratch
import Testing

@testable import MultishellCore
@testable import MultishellProcess

extension ShellIntegrationThroughHelperTests {
  @Test(arguments: InstalledShells.fishes)
  func fishRunsTheUsersConfigThenReportsEachCommandAndItsExit(fish: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }
    let recorder = listener.recorder

    let home = try Scratch.directory("fish")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.fishInitFile(in: home)
    let config = home.appendingPathComponent(".config/fish", isDirectory: true)
    try FileManager.default.createDirectory(at: config, withIntermediateDirectories: true)
    try "set -gx MULTISHELL_USER_RC_LOADED yes\n".write(
      to: config.appendingPathComponent("config.fish"),
      atomically: true,
      encoding: .utf8,
    )

    let session = UUID()
    let environment = ShellTab.fishEnvironment(
      socket: listener.path,
      home: home,
      session: session,
      worktree: "/w/repo",
    )
    let script = """
      printf 'loaded=%s\\n' $MULTISHELL_USER_RC_LOADED
      emit fish_preexec 'FOO=1 command /usr/local/bin/claude --resume'
      set CMD_DURATION 1500; true; emit fish_postexec true
      emit fish_preexec false
      set CMD_DURATION 7; false; emit fish_postexec false
      """
    let output = try await ShellTab.runFish(
      fish,
      initFile: initFile,
      script: script,
      in: home,
      environment: environment,
    )

    #expect(
      output.standardOutput.contains("loaded=yes"),
      "the user's config.fish did not run: \(output.standardOutput) \(output.standardError)",
    )
    try await waitUntil { recorder.received.count >= 5 }
    let reports = recorder.received.compactMap(SessionStateReport.parse)
    #expect(reports.map(\.state) == [.running, .done, .running, .failed, .idle], "\(reports)")
    #expect(reports.allSatisfy { $0.sessionID == session && $0.workingDirectory == "/w/repo" })
    #expect(reports.first?.command == "claude", "the agent past its prefixes and its path")
    #expect(reports.first?.pid != nil, "the shell's pid, for the watch")
    #expect(reports.dropFirst(2).first?.command?.isEmpty != false, "a plain command names none")
    #expect(reports.compactMap(\.duration) == [1.5, 0.007])
  }

  @Test(arguments: InstalledShells.fishes)
  func fishOutsideATabReportsNothing(fish: String) async throws {
    let listener = try ReportListener()
    defer { listener.stop() }

    let home = try Scratch.directory("fish-outside")
    defer { Scratch.remove(home) }
    let initFile = try ShellTab.fishInitFile(in: home)
    var environment = ShellTab.fishEnvironment(socket: listener.path, home: home)
    environment[SessionEnvironment.sessionVariable] = ""

    let output = try await ShellTab.runFish(
      fish,
      initFile: initFile,
      script: "emit fish_preexec true; emit fish_postexec true; functions -q _multishell_preexec",
      in: home,
      environment: environment,
    )

    #expect(output.status != 0, "no hook was defined")
    let lines = try await listener.linesUpToABarrier()
    #expect(lines.count == 1, "only the barrier: \(lines)")
  }
}
