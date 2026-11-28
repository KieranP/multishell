import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionKeysTests {
  private let controlOptionS = KeyCombination(.character("s"), [.control, .option])

  @Test func keysAMenuCommandHoldsAreRefusedAndNeverTakenFromIt() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )

    let judgement = harness.model.setActionKeys(
      KeyCombination.command("t"),
      forAction: "Serve",
      in: harness.project,
    )

    #expect(judgement == .taken(holder: .newTab))
    #expect(harness.model.ownSettings(of: harness.project).actionShortcuts == ActionShortcuts())
    #expect(harness.model.shortcutKeys(for: .newTab) == .command("t"))
  }

  @Test func anActionsKeysAreTakenFromThePanesAndGivenBackWhenCleared() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )

    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)
    #expect(harness.engine.unbound.contains(controlOptionS))
    #expect(harness.model.actionKeysNote(forAction: "Serve", in: harness.project) != nil)

    harness.model.setActionKeys(nil, forAction: "Serve", in: harness.project)
    #expect(!harness.engine.unbound.contains(controlOptionS))
  }

  @Test func keysOnARowWithNoCommandAreNotTakenFromThePanes() {
    let harness = Harness()
    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Serve", at: 0, in: harness.project)

    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    #expect(!harness.engine.unbound.contains(controlOptionS))
  }

  @Test func trustingAFileGivesItsActionsKeysToTheMenu() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Start Server", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setActionKeys(controlOptionS, forAction: "Start Server", in: harness.project)
    #expect(!harness.engine.unbound.contains(controlOptionS))

    harness.model.setTrustsSharedSettings(true, for: harness.project)

    #expect(harness.engine.unbound.contains(controlOptionS))
  }

  @Test func aFileChangedOnDiskTakesItsActionsKeysOutOfThePanesOrGivesThemBack() async throws {
    let harness = Harness()
    let file = SharedProjectSettings.file(in: harness.root)
    try #"{ "actions": [ { "name": "Start Server", "command": "npm start" } ] }"#.write(
      to: file,
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    harness.model.setActionKeys(controlOptionS, forAction: "Start Server", in: harness.project)
    #expect(harness.engine.unbound.contains(controlOptionS))

    try #"{ "actions": [ { "name": "Start Server", "command": "npm run start" } ] }"#.write(
      to: file,
      atomically: true,
      encoding: .utf8,
    )
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: 60)],
      ofItemAtPath: file.path,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    #expect(!harness.engine.unbound.contains(controlOptionS), "the new bytes are not trusted")
  }

  @Test func removingAnActionBeforeTheFileIsReadKeepsTheFilesActionsKeys() throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Serve", "command": "x" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    harness.model.removeAction(at: 0, from: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Serve")
        == controlOptionS
    )
  }

  @Test func renamingOntoANameBeforeTheFileIsReadKeepsTheFilesActionsKeys() throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Serve", "command": "x" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    var settings = ProjectSettings(actions: [ProjectAction(name: "Seed", command: "bin/seed")])
    settings.actionShortcuts.set(controlOptionS, for: "Serve")
    harness.model.setSettings(settings, for: harness.project)

    harness.model.setActionName("Serve", at: 0, in: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Serve")
        == controlOptionS
    )
  }

  @Test func removingAnActionWhileTheFileWillNotReadKeepsTheFilesActionsKeys() async throws {
    let harness = Harness()
    let controlOptionD = KeyCombination(.character("d"), [.control, .option])
    let file = SharedProjectSettings.file(in: harness.root)
    try #"{ "actions": [ { "name": "Seed", "command": "bin/rails db:seed" } ] }"#.write(
      to: file,
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    harness.model.setActionKeys(controlOptionD, forAction: "Seed", in: harness.project)
    harness.model.addAction(to: harness.project)
    try #"{ "actions": [ "#.write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: 60)],
      ofItemAtPath: file.path,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    harness.model.removeAction(at: 0, from: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Seed")
        == controlOptionD
    )
  }

  @Test func renamingOntoANameWhileTheFileWillNotReadKeepsTheFilesActionsKeys() async throws {
    let harness = Harness()
    let controlOptionD = KeyCombination(.character("d"), [.control, .option])
    let file = SharedProjectSettings.file(in: harness.root)
    try #"{ "actions": [ { "name": "Seed", "command": "bin/rails db:seed" } ] }"#.write(
      to: file,
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    harness.model.setActionKeys(controlOptionD, forAction: "Seed", in: harness.project)
    harness.model.addAction(to: harness.project)
    try #"{ "actions": [ "#.write(to: file, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes(
      [.modificationDate: Date(timeIntervalSinceNow: 60)],
      ofItemAtPath: file.path,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    harness.model.setActionName("Seed", at: 0, in: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Seed")
        == controlOptionD
    )
  }

  @Test func removingAProjectFromAnOlderCopyGivesItsActionsKeysBack() {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )
    let olderCopy = harness.project
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)
    #expect(harness.engine.unbound.contains(controlOptionS))

    harness.model.removeProject(olderCopy)

    #expect(!harness.engine.unbound.contains(controlOptionS))
  }
}
