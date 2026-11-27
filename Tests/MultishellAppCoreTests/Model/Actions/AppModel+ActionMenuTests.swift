import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionMenuTests {
  private let migrate = ProjectAction(name: "Run Migrations", command: "bin/rails db:migrate")

  @Test func aProjectWithNoActionsStillHasAMenuToEditThemFrom() throws {
    let harness = Harness()

    let menu = try #require(harness.model.actionMenu(for: harness.main))

    #expect(menu.items.isEmpty && menu.awaitingTrust.isEmpty)
  }

  @Test func theMenuListsEachActionWithItsStateAndKeys() throws {
    let harness = Harness()
    let keys = KeyCombination(.character("s"), [.control, .option])
    var shortcuts = ActionShortcuts()
    shortcuts.set(keys, for: ProjectAction.serve.name)
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction.serve, migrate], actionShortcuts: shortcuts),
      for: harness.project,
    )
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true)
    )

    let menu = try #require(harness.model.actionMenu(for: harness.main))

    #expect(menu.items.map(\.name) == [ProjectAction.serve.name, migrate.name])
    #expect(menu.items[0].state.isRunning)
    #expect(menu.items[0].keys == keys)
    #expect(menu.items[1].state == .idle && menu.items[1].keys == nil)
    #expect(menu.isAnyRunning)
    #expect(harness.model.actionMenu(for: harness.feature)?.isAnyRunning == false)
  }

  @Test func aFailedRunShowsAsFailedUntilItRunsAgain() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true)
    )

    harness.model.noteCommandFinished(in: session.id, exitCode: 1)

    #expect(harness.model.actionMenu(for: harness.main)?.items.first?.state == .failed)
  }

  @Test func anUntrustedFilesActionsAreListedToTrustAndNeverRun() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Start Server", "command": "npm run dev" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    let menu = try #require(harness.model.actionMenu(for: harness.main))
    #expect(menu.items.isEmpty)
    #expect(menu.awaitingTrust == [ProjectAction.serve.name])

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.workspace.tabs.isEmpty)

    harness.model.setTrustsSharedSettings(true, for: harness.project)
    #expect(
      harness.model.actionMenu(for: harness.main)?.items.map(\.name) == [ProjectAction.serve.name]
    )
    #expect(harness.model.actionMenu(for: harness.main)?.awaitingTrust == [])
  }

  @Test func theMenuBarListsTheSelectedWorktreesActionsWithTheirKeys() {
    let harness = Harness()
    let keys = KeyCombination(.character("s"), [.control, .option])
    var shortcuts = ActionShortcuts()
    shortcuts.set(keys, for: ProjectAction.serve.name)
    harness.model.setSettings(
      ProjectSettings(actions: [ProjectAction.serve, migrate], actionShortcuts: shortcuts),
      for: harness.project,
    )
    #expect(harness.model.actionMenuBarGroups.isEmpty, "nothing selected")

    harness.model.select(harness.main)

    #expect(
      harness.model.actionMenuBarGroups.flatMap(\.self) == [
        ActionMenuBarItem(name: ProjectAction.serve.name, keys: keys),
        ActionMenuBarItem(name: migrate.name, keys: nil),
      ]
    )
  }

  @Test func aRunsAgeCountsFromItsStartWhateverItsTabsDotDoesSince() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try #require(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id)
    )
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, isFromShellIntegration: true)
    )
    let started = harness.model.actionMenu(for: harness.main)?.items.first?.state

    harness.messageSource.send(SessionStateReport(state: .attention, sessionID: session.id))

    let state = harness.model.actionMenu(for: harness.main)?.items.first?.state
    #expect(state?.isRunning == true)
    #expect(state == started)
  }

  @Test func editActionsOpensTheSettingsWindowOnTheProjectsActionsPage() {
    let harness = Harness()
    harness.model.settingsSearchText = "keys"

    harness.model.editActions(of: harness.main)

    #expect(harness.platform.shownWindows == [.settings])
    #expect(harness.model.settingsLocation.section == .actions)
    #expect(harness.model.settingsLocation.scope == .project(harness.project.id))
    #expect(harness.model.settingsSearchText.isEmpty)
  }

  @Test func theUsersOwnAndTheFilesActionsAreGroupedApartInBothMenus() async throws {
    let harness = Harness()
    try #"{ "actions": [ { "name": "Deploy", "command": "bin/deploy" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
    var settings = harness.model.ownSettings(of: harness.project)
    settings.actions = [ProjectAction.serve]
    harness.model.setSettings(settings, for: harness.project)
    harness.model.select(harness.main)

    let menu = try #require(harness.model.actionMenu(for: harness.main))
    #expect(menu.groups.map { $0.map(\.name) } == [[ProjectAction.serve.name], ["Deploy"]])
    #expect(
      harness.model.actionMenuBarGroups.map { $0.map(\.name) } == [
        [ProjectAction.serve.name], ["Deploy"],
      ]
    )

    settings.actions = []
    harness.model.setSettings(settings, for: harness.project)
    #expect(
      harness.model.actionMenu(for: harness.main)?.groups.map { $0.map(\.name) } == [["Deploy"]]
    )
  }
}
