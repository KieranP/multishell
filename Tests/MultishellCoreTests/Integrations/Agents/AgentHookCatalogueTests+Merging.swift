import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Adding to and removing from a settings file someone else keeps.
extension AgentHookCatalogueTests {
  @Test func addingLeavesOtherHooksAndOtherSettingsAlone() throws {
    let existing: [String: Any] = [
      "model": "opus",
      "permissions": ["allow": ["Bash(git *)"]],
      "hooks": [
        "Notification": [
          ["hooks": [["type": "command", "command": "curl -sf http://127.0.0.1:9/hook"]]]
        ],
        "PreCompact": [["hooks": [["type": "command", "command": "echo compacting"]]]],
      ],
    ]
    #expect(!AgentHookCatalogue.claude.isInstalled(in: existing))

    let added = AgentHookCatalogue.claude.adding(to: existing, helper: helper)

    #expect(AgentHookCatalogue.claude.isInstalled(in: added))
    #expect(added["model"] as? String == "opus")
    #expect((added["permissions"] as? [String: Any])?["allow"] as? [String] == ["Bash(git *)"])
    let hooks = try #require(added["hooks"] as? [String: Any])
    let notification = try #require(hooks["Notification"] as? [[String: Any]])
    #expect(notification.count == 2, "the curl hook stays, ours is appended")
    #expect(command(of: notification[0]).hasPrefix("curl"))
    #expect(AgentHookCatalogue.isMultishellHook(command(of: notification[1])))
    #expect((hooks["PreCompact"] as? [[String: Any]])?.count == 1, "an event we do not hook")

    let twice = AgentHookCatalogue.claude.adding(to: added, helper: helper)
    #expect(
      (try #require(twice["hooks"] as? [String: Any])["Stop"] as? [[String: Any]])?.count == 1,
      "adding again adds nothing")
  }

  /// Two agents can share neither a file nor an event name, but the same
  /// settings shape: removing one must not take the other's line.
  @Test func removingTakesOnlyOursAndDropsEmptiedEvents() throws {
    let existing: [String: Any] = [
      "hooks": [
        "Notification": [
          ["hooks": [["type": "command", "command": "curl -sf http://127.0.0.1:9/hook"]]]
        ]
      ]
    ]
    let removed = AgentHookCatalogue.claude.removing(
      from: AgentHookCatalogue.claude.adding(to: existing, helper: helper))

    let hooks = try #require(removed["hooks"] as? [String: Any])
    #expect(Set(hooks.keys) == ["Notification"], "Stop and the rest held only ours")
    #expect((hooks["Notification"] as? [[String: Any]])?.count == 1)
    #expect(!AgentHookCatalogue.claude.isInstalled(in: removed))

    let bare = AgentHookCatalogue.claude.removing(
      from: AgentHookCatalogue.claude.adding(to: [:], helper: helper))
    #expect(bare["hooks"] == nil, "no hooks left means no hooks key")
  }

  /// Add only ever appends a group of its own, so a group holding one of
  /// theirs beside ours is hand-written and not ours to drop whole.
  @Test func removingKeepsAHookTheUserPutInOurGroup() throws {
    let ours = AgentHookCatalogue.claude.adding(to: [:], helper: helper)
    var hooks = try #require(ours["hooks"] as? [String: Any])
    var groups = try #require(hooks["Stop"] as? [[String: Any]])
    var group = try #require(groups.first)
    var entries = try #require(group["hooks"] as? [[String: Any]])
    entries.append(["type": "command", "command": "~/bin/audit-log.sh"])
    group["hooks"] = entries
    groups[0] = group
    hooks["Stop"] = groups

    let removed = AgentHookCatalogue.claude.removing(from: ["hooks": hooks])

    let left = try #require(removed["hooks"] as? [String: Any])
    let stop = try #require(left["Stop"] as? [[String: Any]])
    let commands = stop.flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
      .compactMap { $0["command"] as? String }
    #expect(commands == ["~/bin/audit-log.sh"])
    #expect(!AgentHookCatalogue.claude.isInstalled(in: removed))
  }

  @Test func removingSplitsAHandWrittenGroupMixingTheTwoShapes() throws {
    let ours = AgentHookCatalogue.command(agent: AgentCatalogue.claudeID, helper: helper)
    let mixed: [String: Any] = [
      "hooks": [
        "Stop": [
          [
            "type": "command", "command": ours, "timeout": 5,
            "hooks": [["type": "command", "command": "~/bin/theirs.sh"]],
          ],
          [
            "type": "command", "command": "~/bin/also-theirs.sh",
            "hooks": [["type": "command", "command": ours]],
          ],
        ]
      ]
    ]

    let removed = AgentHookCatalogue.claude.removing(from: mixed)

    let left = try #require(removed["hooks"] as? [String: Any])
    let stop = try #require(left["Stop"] as? [[String: Any]])
    #expect(stop.count == 2)
    #expect(stop.first?["command"] == nil)
    #expect(stop.first?["timeout"] == nil)
    #expect(
      (stop.first?["hooks"] as? [[String: Any]])?.compactMap { $0["command"] as? String }
        == ["~/bin/theirs.sh"])
    #expect(stop.last?["command"] as? String == "~/bin/also-theirs.sh")
    #expect(stop.last?["hooks"] == nil)
    #expect(!AgentHookCatalogue.claude.holdsAnyOfOurs(removed))
  }

  /// Remove on a file that has none of ours rewrites nothing: the write
  /// sorts keys and re-indents, and takes a backup copy nobody asked for.
  @Test func removingNothingLeavesTheFileAndMakesNoBackup() throws {
    let directory = try Scratch.directory("hooks")
    defer { Scratch.remove(directory) }
    let file = directory.appendingPathComponent("settings.json")
    let theirs = #"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"echo bye"}]}]},"z":1}"#
    try theirs.write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.claude.remove(from: file)

    #expect(try String(contentsOf: file, encoding: .utf8) == theirs, "rewritten for nothing")
    let beside = try FileManager.default.contentsOfDirectory(atPath: directory.path)
    #expect(beside == ["settings.json"], "a backup of a file we did not change: \(beside)")

    // Half of ours, under one event only: still ours to take back. The check
    // cannot be `isInstalled`, which wants one under every event.
    let half = AgentHookCatalogue.claude.adding(to: [:], helper: helper)
    var hooks = try #require(half["hooks"] as? [String: Any])
    let one = try #require(hooks["Stop"])
    hooks = ["Stop": one]
    try AgentSettingsFile.write(["hooks": hooks], to: file)
    #expect(!AgentHookCatalogue.claude.isInstalled(in: file), "not by that measure")

    try AgentHookCatalogue.claude.remove(from: file)
    let left = try AgentSettingsFile.read(file)
    #expect(left["hooks"] == nil, "our one entry was still ours to remove")
  }

  /// A string, an object or a later agent's shape under an event is the user's: none of
  /// it was ever ours, so Remove must not carry it off nor Add write over it.
  @Test func anEntryThisCannotReadIsLeftToTheUser() throws {
    let existing: [String: Any] = [
      "hooks": [
        "Stop": ["echo done"],
        "PreToolUse": ["command": "echo before"],
        "Notification": [["hooks": [["type": "command", "command": "say hi"]]]],
      ]
    ]

    let removed = AgentHookCatalogue.claude.removing(from: existing)
    let afterRemove = try #require(removed["hooks"] as? [String: Any])
    #expect(afterRemove["Stop"] as? [String] == ["echo done"], "a string list is not ours to drop")
    #expect(
      (afterRemove["PreToolUse"] as? [String: Any])?["command"] as? String == "echo before",
      "nor is an object")
    #expect((afterRemove["Notification"] as? [[String: Any]])?.count == 1, "and the readable stays")

    let added = AgentHookCatalogue.claude.adding(to: existing, helper: helper)
    let afterAdd = try #require(added["hooks"] as? [String: Any])
    #expect(afterAdd["Stop"] as? [String] == ["echo done"], "not written over either")
    #expect((afterAdd["PreToolUse"] as? [String: Any])?["command"] as? String == "echo before")
    #expect((afterAdd["Notification"] as? [[String: Any]])?.count == 2, "ours joins the readable")
  }

  /// Leaving it alone in silence would leave a row that never says
  /// Installed, so the install refuses and names the event.
  @Test func installingRefusesAFileWhoseEntriesItCannotRead() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let original = #"{"hooks":{"Stop":"echo done"}}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnreadableHookEntries.self) {
      try AgentHookCatalogue.claude.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "not a byte written")
    #expect(!AgentHookCatalogue.claude.isInstalled(in: file))
    #expect(
      AgentHookCatalogue.claude.unreadableEvents(in: try AgentSettingsFile.read(file)) == ["Stop"])
  }

  /// Every existing install predates the two counting events, so Add has to
  /// top them up without doubling the seven that are already there.
  @Test func addingOverAnOlderInstallFillsOnlyWhatIsMissing() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")

    // The file as a build before the counting events left it.
    let older = AgentHookIntegration(
      id: AgentCatalogue.claudeID, file: file, displayPath: "x",
      events: AgentHookCatalogue.claude.events.filter { $0.subagentPhase == nil },
      format: .sharedSettings(millisecondTimeout: false))
    try older.install(into: file, helper: helper)
    #expect(older.isInstalled(in: file))
    #expect(!AgentHookCatalogue.claude.isInstalled(in: file), "so the row offers Add again")

    try AgentHookCatalogue.claude.install(into: file, helper: helper)

    #expect(AgentHookCatalogue.claude.isInstalled(in: file))
    let hooks = try #require(try AgentSettingsFile.read(file)["hooks"] as? [String: Any])
    for event in AgentHookCatalogue.claude.events {
      let groups = try #require(hooks[event.name] as? [[String: Any]], "\(event.name)")
      #expect(groups.count == 1, "\(event.name) gained a second copy of ours")
    }
  }

  /// A list or a string under `hooks` is something this cannot put back, so
  /// the install refuses it rather than writing over it.
  @Test func installingRefusesAFileWhoseHooksAreNotAnObject() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    let original = #"{"hooks":["Stop"]}"#
    try original.write(to: file, atomically: true, encoding: .utf8)

    #expect(throws: UnreadableHookSection.self) {
      try AgentHookCatalogue.claude.install(into: file, helper: helper)
    }
    #expect(try String(contentsOf: file, encoding: .utf8) == original, "not a byte written")
    #expect(!AgentHookCatalogue.claude.isInstalled(in: file))
  }

  /// An explicit `null` is not a shape to preserve, it is the key being
  /// absent spelled out, so the install goes ahead as for a file without it.
  @Test func installingTreatsANullHooksKeyAsNoHooksAtAll() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("settings.json")
    try #"{"hooks":null,"model":"opus"}"#.write(to: file, atomically: true, encoding: .utf8)

    try AgentHookCatalogue.claude.install(into: file, helper: helper)

    #expect(AgentHookCatalogue.claude.isInstalled(in: file))
    let settings = try AgentSettingsFile.read(file)
    #expect(settings["model"] as? String == "opus", "the rest of the file is kept")
  }

  @Test func installingIntoAFileCreatesItKeepsABackupAndIsIdempotent() throws {
    let directory = temporaryDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent(".claude/settings.json")
    let claude = AgentHookCatalogue.claude

    #expect(!claude.isInstalled(in: file))
    try claude.install(into: file, helper: helper)
    #expect(claude.isInstalled(in: file))
    #expect(
      !FileManager.default.fileExists(
        atPath: file.appendingPathExtension("before-multishell").path),
      "nothing to back up when the file did not exist")

    // A hand-edited file with other content gets a backup once.
    try #"{ "model": "opus", "hooks": {} }"#.write(to: file, atomically: true, encoding: .utf8)
    try claude.install(into: file, helper: helper)
    let backup = file.appendingPathExtension("before-multishell")
    #expect(try String(contentsOf: backup, encoding: .utf8).contains("\"model\": \"opus\""))
    let written = try AgentSettingsFile.read(file)
    #expect(written["model"] as? String == "opus")
    #expect(claude.isInstalled(in: written))

    try claude.install(into: file, helper: helper)
    #expect(
      try String(contentsOf: backup, encoding: .utf8).contains("\"hooks\": {}"),
      "the backup is the pre-Multishell file, not overwritten by a later install")

    try claude.remove(from: file)
    #expect(!claude.isInstalled(in: file))
    #expect(try AgentSettingsFile.read(file)["model"] as? String == "opus")
  }

  private func command(of group: [String: Any]) -> String {
    ((group["hooks"] as? [[String: Any]])?.first?["command"] as? String) ?? ""
  }
}
