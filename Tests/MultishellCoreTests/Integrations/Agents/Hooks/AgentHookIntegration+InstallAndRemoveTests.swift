import Foundation
import TestScratch
import Testing

@testable import MultishellCore

@Suite
struct AgentHookIntegrationInstallAndRemoveTests: AgentHookFixtures {
  /// Remove on a file that has none of ours rewrites nothing: the write
  /// sorts keys and re-indents, and takes a backup copy nobody asked for.
  @Test func removingNothingLeavesTheFileAndMakesNoBackup() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }
    let theirs = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo bye"}]}]},"z":1}"#
    try theirs.write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.claude.remove(from: file)

    #expect(try String(contentsOf: file, encoding: .utf8) == theirs, "rewritten for nothing")
    let beside = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(beside == ["settings.json"], "a backup of a file we did not change: \(beside)")
  }

  /// The check cannot be `hasOurHookUnderEveryEvent`, which wants one of ours
  /// under every event.
  @Test func removeTakesBackAHalfWrittenInstall() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }
    let half = AgentHookCatalogue.claude.adding(to: [:], helper: helper)
    var hooks = try #require(half["hooks"] as? [String: Any])
    let one = try #require(hooks["Stop"])
    hooks = ["Stop": one]
    try AgentHookFile.write(["hooks": hooks], to: file)
    #expect(!AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file), "not by that measure")

    try AgentHookCatalogue.claude.remove(from: file)
    let left = try AgentHookFile.read(file)
    #expect(left["hooks"] == nil, "our one entry was still ours to remove")
  }

  /// Leaving it alone in silence would leave a row that never says
  /// Installed, so the install refuses and names the event.
  @Test func installingRefusesAFileWhoseEntriesItCannotRead() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }
    let original = #"{"hooks":{"Stop":"echo done"}}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnexpectedHookEntriesShape.self) {
      try AgentHookCatalogue.claude.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "not a byte written")
    #expect(!AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file))
    #expect(
      AgentHookCatalogue.claude.eventsOfUnexpectedShape(in: try AgentHookFile.read(file)) == [
        "Stop"
      ]
    )
  }

  /// An install from before the two counting events lacks them, so Add tops them
  /// up without doubling what is already there.
  @Test func addingOverAnOlderInstallFillsOnlyWhatIsMissing() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }

    let beforeCountingEvents = AgentHookIntegration(
      id: AgentCatalogue.claudeID,
      file: file,
      events: AgentHookCatalogue.claude.events.filter { $0.subagentPhase == nil },
      format: .userSettingsFile(timeoutIsInMilliseconds: false),
    )
    try beforeCountingEvents.install(into: file, helper: helper)
    #expect(beforeCountingEvents.hasOurHookUnderEveryEvent(in: file))
    #expect(
      !AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file),
      "so the row offers Add again",
    )

    try AgentHookCatalogue.claude.install(into: file, helper: helper)

    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file))
    let hooks = try #require(try AgentHookFile.read(file)["hooks"] as? [String: Any])
    for event in AgentHookCatalogue.claude.events {
      let groups = try #require(hooks[event.name] as? [[String: Any]], "\(event.name)")
      #expect(groups.count == 1, "\(event.name) gained a second copy of ours")
    }
  }

  /// A list or a string under `hooks` is something this cannot put back, so
  /// the install refuses it rather than writing over it.
  @Test func installingRefusesAFileWhoseHooksAreNotAnObject() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }
    let original = #"{"hooks":["Stop"]}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnexpectedHookSectionShape.self) {
      try AgentHookCatalogue.claude.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "not a byte written")
    #expect(!AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file))
  }

  /// An explicit `null` is not a shape to preserve, it is the key being
  /// absent spelled out, so the install goes ahead as for a file without it.
  @Test func installingTreatsANullHooksKeyAsNoHooksAtAll() throws {
    let (directory, file) = try scratchSettingsFile()
    defer { Scratch.remove(directory) }
    try #"{"hooks":null,"model":"opus"}"#.write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.claude.install(into: file, helper: helper)

    #expect(AgentHookCatalogue.claude.hasOurHookUnderEveryEvent(in: file))
    let settings = try AgentHookFile.read(file)
    #expect(settings["model"] as? String == "opus", "the rest of the file is kept")
  }

  @Test func installingIntoAFileCreatesItKeepsABackupAndIsIdempotent() throws {
    let directory = Scratch.path("hooks")
    defer { Scratch.remove(directory) }
    let file = directory.appendingPathComponent(".claude/settings.json")
    let claude = AgentHookCatalogue.claude

    #expect(!claude.hasOurHookUnderEveryEvent(in: file))
    try claude.install(into: file, helper: helper)
    #expect(claude.hasOurHookUnderEveryEvent(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path
      ),
      "nothing to back up when the file did not exist",
    )

    try #"{ "model": "opus", "hooks": {} }"#.write(to: file, atomically: true, encoding: .utf8)
    try claude.install(into: file, helper: helper)
    let backup = file.appendingPathExtension("before-multishell")
    #expect(try String(contentsOf: backup, encoding: .utf8).contains("\"model\": \"opus\""))
    let written = try AgentHookFile.read(file)
    #expect(written["model"] as? String == "opus")
    #expect(claude.hasOurHookUnderEveryEvent(in: written))

    try claude.install(into: file, helper: helper)
    #expect(
      try String(contentsOf: backup, encoding: .utf8).contains("\"hooks\": {}"),
      "the backup is the pre-Multishell file, not overwritten by a later install",
    )

    try claude.remove(from: file)
    #expect(!claude.hasOurHookUnderEveryEvent(in: file))
    #expect(try AgentHookFile.read(file)["model"] as? String == "opus")
  }
}
