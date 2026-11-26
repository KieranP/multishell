import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionEditingTests {
  private let controlOptionS = KeyCombination(.character("s"), [.control, .option])

  @Test func anAddedRowStartsBlankAndIsNotInForceUntilNamedWithACommand() throws {
    let harness = Harness()

    harness.model.addAction(to: harness.project)
    harness.model.addAction(to: harness.project)

    let rows = harness.model.ownSettings(of: harness.project).actions
    #expect(rows.map(\.name) == ["", ""])
    #expect(rows[0].id != rows[1].id)
    harness.model.setActionCommand("npm run dev", at: 0, in: harness.project)
    #expect(harness.model.actionMenu(for: harness.main)?.items == [])

    harness.model.setActionName("Serve", at: 0, in: harness.project)
    #expect(harness.model.actionMenu(for: harness.main)?.items.map(\.name) == ["Serve"])
  }

  @Test func namingAndFillingInARowKeepsItsIdentityForItsFields() throws {
    let harness = Harness()
    harness.model.addAction(to: harness.project)
    let added = try #require(harness.model.ownSettings(of: harness.project).actions.first)

    harness.model.setActionName("Serve", at: 0, in: harness.project)
    harness.model.setActionCommand("npm run dev", at: 0, in: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).actions.first?.id == added.id)
  }

  @Test func aRenamedActionKeepsItsKeysAndARemovedOneFreesThem() throws {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    harness.model.setActionName("Start Server", at: 0, in: harness.project)
    #expect(
      harness.model.actionMenu(for: harness.main)?.items.first?.keys == controlOptionS
    )

    harness.model.removeAction(at: 0, from: harness.project)
    #expect(harness.model.ownSettings(of: harness.project).actionShortcuts == ActionShortcuts())
  }

  @Test func aNameAnotherOwnActionHasIsRefusedAndBothKeepTheirKeys() {
    let harness = Harness()
    let controlOptionT = KeyCombination(.character("t"), [.control, .option])
    harness.model.setSettings(
      ProjectSettings(actions: [
        ProjectAction(name: "St", command: "a"), ProjectAction(name: "Start", command: "b"),
      ]),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionT, forAction: "St", in: harness.project)
    harness.model.setActionKeys(controlOptionS, forAction: "Start", in: harness.project)

    let renamed = harness.model.setActionName("St", at: 1, in: harness.project)

    let settings = harness.model.ownSettings(of: harness.project)
    #expect(renamed == nil)
    #expect(settings.actions.map(\.name) == ["St", "Start"])
    #expect(settings.actionShortcuts.keys(for: "St") == controlOptionT)
    #expect(settings.actionShortcuts.keys(for: "Start") == controlOptionS)
  }

  @Test func aNameIsTrimmedSoItsKeysSurviveARelaunch() throws {
    let harness = Harness()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Serve", command: "npm run dev")]),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    harness.model.setActionName(" Start Server ", at: 0, in: harness.project)

    let reloaded = try JSONDecoder().decode(
      ProjectSettings.self,
      from: try JSONEncoder().encode(harness.model.ownSettings(of: harness.project)),
    )
    #expect(reloaded.actions.map(\.name) == ["Start Server"])
    #expect(reloaded.actionShortcuts.keys(for: "Start Server") == controlOptionS)
  }

  @Test func standingInForAFilesActionAndStoppingKeepsThatActionsKeys() async throws {
    let harness = Harness()
    let controlOptionD = KeyCombination(.character("d"), [.control, .option])
    try #"{ "actions": [ { "name": "Seed", "command": "bin/rails db:seed" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    harness.model.setActionKeys(controlOptionD, forAction: "Seed", in: harness.project)
    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Draft", at: 0, in: harness.project)
    harness.model.setActionCommand("bin/reset", at: 0, in: harness.project)
    harness.model.setActionKeys(controlOptionS, forAction: "Draft", in: harness.project)

    harness.model.setActionName("Seed", at: 0, in: harness.project)
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Seed")
        == controlOptionD
    )

    harness.model.setActionName("Reset", at: 0, in: harness.project)
    let shortcuts = harness.model.ownSettings(of: harness.project).actionShortcuts
    #expect(shortcuts.keys(for: "Seed") == controlOptionD)
    #expect(shortcuts.keys(for: "Reset") == nil)
  }

  @Test func renamingAwayFromAnUntrustedFilesNameCarriesTheTabsAndKeys() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Start Server", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction(name: "Start Server", command: "bin/dev")]),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionS, forAction: "Start Server", in: harness.project)
    harness.model.runAction(named: "Start Server", in: harness.main)

    harness.model.setActionName("Serve", at: 0, in: harness.project)

    #expect(harness.model.actionSession(named: "Serve", in: harness.main.id) != nil)
    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Serve")
        == controlOptionS
    )
  }

  @Test func keysARenameDropsAreGivenBackToThePanes() async throws {
    let harness = Harness()
    let controlOptionD = KeyCombination(.character("d"), [.control, .option])
    try #"{ "actions": [ { "name": "Start Server", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    harness.model.setActionKeys(controlOptionS, forAction: "Start Server", in: harness.project)
    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Deploy", at: 0, in: harness.project)
    harness.model.setActionCommand("bin/deploy", at: 0, in: harness.project)
    harness.model.setActionKeys(controlOptionD, forAction: "Deploy", in: harness.project)
    #expect(harness.engine.unbound.contains(controlOptionD))

    harness.model.setActionName("Start Server", at: 0, in: harness.project)

    #expect(!harness.engine.unbound.contains(controlOptionD))
  }

  @Test func fillingInARowsCommandTakesItsKeysFromThePanesAndClearingGivesThemBack() {
    let harness = Harness()
    harness.model.addAction(to: harness.project)
    harness.model.setActionName("Serve", at: 0, in: harness.project)
    harness.model.setActionKeys(controlOptionS, forAction: "Serve", in: harness.project)

    harness.model.setActionCommand("bin/dev", at: 0, in: harness.project)
    #expect(harness.engine.unbound.contains(controlOptionS))

    harness.model.setActionCommand("", at: 0, in: harness.project)
    #expect(!harness.engine.unbound.contains(controlOptionS))
  }

  @Test func namingANewRowNeverInheritsKeysADroppedRowLeftUnderThatName() {
    let harness = Harness()
    var leftOver = ActionShortcuts()
    leftOver.set(controlOptionS, for: "Gone")
    harness.model.setSettings(ProjectSettings(actionShortcuts: leftOver), for: harness.project)
    harness.model.addAction(to: harness.project)

    harness.model.setActionName("Gone", at: 0, in: harness.project)

    #expect(harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Gone") == nil)
  }

  @Test func renamingOntoANameOnlyLeftOverKeysHoldKeepsTheActionsOwnKeys() {
    let harness = Harness()
    let controlOptionD = KeyCombination(.character("d"), [.control, .option])
    var shortcuts = ActionShortcuts()
    shortcuts.set(controlOptionS, for: "Gone")
    harness.model.setSettings(
      ProjectSettings(
        actions: [ProjectAction(name: "Deploy", command: "bin/deploy")],
        actionShortcuts: shortcuts,
      ),
      for: harness.project,
    )
    harness.model.setActionKeys(controlOptionD, forAction: "Deploy", in: harness.project)

    harness.model.setActionName("Gone", at: 0, in: harness.project)

    #expect(
      harness.model.ownSettings(of: harness.project).actionShortcuts.keys(for: "Gone")
        == controlOptionD
    )
  }

  @Test func removingAnActionLetsANewOneOfItsNameStartAfreshInItsOwnTab() throws {
    let harness = Harness()
    let name = "Serve"
    harness.model.addAction(to: harness.project)
    harness.model.setActionName(name, at: 0, in: harness.project)
    harness.model.setActionCommand("npm run dev", at: 0, in: harness.project)
    harness.model.runAction(named: name, in: harness.main)
    let first = try #require(harness.model.actionSession(named: name, in: harness.main.id))
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: first.id, isFromShellIntegration: true)
    )

    harness.model.removeAction(at: 0, from: harness.project)
    harness.model.addAction(to: harness.project)
    harness.model.setActionName(name, at: 0, in: harness.project)
    harness.model.setActionCommand("bin/rails db:migrate", at: 0, in: harness.project)
    harness.model.runAction(named: name, in: harness.main)

    #expect(harness.model.pendingActionRestart == nil)
    #expect(harness.model.actionSession(named: name, in: harness.main.id)?.id != first.id)
  }

  @Test func anAddedRowLeavesAnUntrustedFileActionsKeysAlone() async throws {
    let harness = Harness()
    let name = "Start Server"
    try #"{ "actions": [ { "name": "\#(name)", "command": "npm start" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setActionKeys(controlOptionS, forAction: name, in: harness.project)

    harness.model.addAction(to: harness.project)

    let settings = harness.model.ownSettings(of: harness.project)
    #expect(settings.actions.map(\.name) == [""])
    #expect(settings.actionShortcuts.keys(for: name) == controlOptionS)
  }

  @Test func movingARowPutsItAtTheGivenPlaceAndKeepsItsIdentity() throws {
    let harness = Harness()
    let serve = ProjectAction(name: "Serve", command: "bin/dev")
    let migrate = ProjectAction(name: "Migrate", command: "bin/migrate")
    let seed = ProjectAction(name: "Seed", command: "bin/seed")
    harness.model.setSettings(
      ProjectSettings(actions: [serve, migrate, seed]),
      for: harness.project,
    )
    let moved = try #require(harness.model.ownSettings(of: harness.project).actions.first)

    harness.model.moveAction(moved.id, to: 2, in: harness.project)

    let actions = harness.model.ownSettings(of: harness.project).actions
    #expect(actions == [migrate, seed, serve])
    #expect(actions.last?.id == moved.id)
    #expect(harness.model.actionMenu(for: harness.main)?.items.map(\.name) == actions.map(\.name))
  }
}
