import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelActionRunsTests {
  private func actionSession(_ harness: Harness) throws -> TerminalSession {
    try #require(harness.model.actionSession(named: ProjectAction.serve.name, in: harness.main.id))
  }

  private func reportRunning(_ harness: Harness, in id: TerminalSession.ID) {
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: id, isFromShellIntegration: true)
    )
  }

  @Test func pickingAnActionOpensATabNamedForItThatRunsItsScript() throws {
    let harness = Harness.withServeAction()

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    let session = try actionSession(harness)
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == tab.id)
    #expect(harness.model.title(of: tab) == ProjectAction.serve.name)
    let opened = try #require(harness.engine.opened.last { $0.id == session.id })
    #expect(opened.command?.contains("MULTISHELL_ACTION_SCRIPT=npm run dev") == true)
  }

  @Test func whatTheShellReportsAsATitleNeverRenamesAnActionsTab() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)

    harness.model.noteTitle("~/feature", of: session.id)

    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    #expect(harness.model.shownTitle(of: tab) == ProjectAction.serve.name)
  }

  @Test func anActionStillRunningAsksBeforeRestartingAndRestartReplacesItInItsTab() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    let tab = try #require(harness.model.workspace.tab(owning: first.id))
    reportRunning(harness, in: first.id)
    let openedBefore = harness.engine.opened.count

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    let pending = try #require(harness.model.pendingActionRestart)
    #expect(pending.sessionID == first.id)
    #expect(harness.engine.opened.count == openedBefore, "nothing restarts before the answer")

    harness.model.answerActionRestart(pending, restarts: true)

    let second = try actionSession(harness)
    #expect(second.id != first.id)
    #expect(harness.engine.closed.contains(first.id))
    #expect(harness.model.workspace.tab(owning: second.id)?.id == tab.id)
    #expect(harness.model.workspace.tabs.count == 1)
    let reopened = try #require(harness.engine.opened.last { $0.id == second.id })
    #expect(reopened.command?.contains("MULTISHELL_ACTION_SCRIPT=npm run dev") == true)
  }

  @Test func decliningTheRestartLeavesTheRunningActionAlone() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    reportRunning(harness, in: first.id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    harness.model.answerActionRestart(
      try #require(harness.model.pendingActionRestart),
      restarts: false,
    )

    #expect(harness.model.pendingActionRestart == nil)
    #expect(try actionSession(harness).id == first.id)
    #expect(!harness.engine.closed.contains(first.id))
  }

  @Test func anActionThatEndedRunsAgainInItsOwnTabWithoutAsking() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    let tab = try #require(harness.model.workspace.tab(owning: first.id))
    reportRunning(harness, in: first.id)
    harness.model.noteCommandFinished(in: first.id, exitCode: 1)

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    #expect(harness.model.pendingActionRestart == nil)
    let second = try actionSession(harness)
    #expect(second.id != first.id)
    #expect(harness.model.workspace.tab(owning: second.id)?.id == tab.id)
  }

  @Test func theRestartQuestionGoesWithTheTabItWasAbout() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    reportRunning(harness, in: first.id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)

    harness.model.closeTab(try #require(harness.model.workspace.tab(owning: first.id)).id)

    #expect(harness.model.pendingActionRestart == nil)
  }

  @Test func aRelaunchedActionTabOpensAShellAndStartsNothing() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)

    let relaunch = harness.relaunched()
    relaunch.model.select(try #require(relaunch.store.workspace.worktree(harness.main.id)))

    let reopened = try #require(relaunch.engine.opened.first { $0.id == session.id })
    #expect(reopened.actionName == ProjectAction.serve.name)
    #expect(reopened.command?.contains { $0.contains("MULTISHELL_ACTION_SCRIPT") } != true)
  }

  @Test func anActionNotInForceDoesNothing() {
    let harness = Harness.withServeAction()

    harness.model.runAction(named: "Seed Database", in: harness.main)

    #expect(harness.model.workspace.tabs.isEmpty)
  }

  @Test func anActionStartedFromTheAppSeesItsWorktreesPort() throws {
    let harness = Harness.withServeAction()
    let port = try #require(harness.model.workspace.port(of: harness.main.id))

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    let session = try actionSession(harness)
    let opened = try #require(harness.engine.opened.last { $0.id == session.id })
    #expect(opened.port == port)
    #expect(opened.command?.contains { $0.contains("unset MULTISHELL_PORT") } == false)
  }

  @Test func noActionStartsInAWorktreeWhileItIsBeingRemoved() {
    let harness = Harness.withServeAction()
    harness.model.worktreeOperations.begin(.preDeleteHook, on: harness.main.id)
    harness.model.presentedError = nil

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    #expect(harness.model.workspace.tabs.isEmpty)
  }

  @Test func aRenamedActionStillFindsTheTabItIsRunningIn() async throws {
    let harness = Harness.withServeAction()
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)
    reportRunning(harness, in: session.id)

    harness.model.setActionName("Serve", at: 0, in: harness.project)
    harness.model.runAction(named: "Serve", in: harness.main)

    #expect(harness.model.pendingActionRestart?.sessionID == session.id)
    #expect(harness.model.workspace.tabs.count == 1)
  }

  @Test func aCommandTypedAfterTheActionEndedIsNotTheActionRunningButIsAskedAbout() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)
    reportRunning(harness, in: session.id)
    harness.model.noteCommandFinished(in: session.id, exitCode: 1)
    reportRunning(harness, in: session.id)

    #expect(harness.model.actionMenu(for: harness.main)?.isAnyRunning == false)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.pendingActionRestart?.sessionID == session.id)
  }

  @Test func aRenamedActionsTabTakesItsNewNameAndKeepsItThroughARestart() async throws {
    let harness = Harness.withServeAction()
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    reportRunning(harness, in: first.id)

    harness.model.setActionName("Serve", at: 0, in: harness.project)
    harness.model.runAction(named: "Serve", in: harness.main)
    harness.model.answerActionRestart(
      try #require(harness.model.pendingActionRestart),
      restarts: true,
    )

    let tab = try #require(harness.model.workspace.tabs.first)
    #expect(harness.model.title(of: tab) == "Serve")
  }

  @Test func restartAnsweredAfterARenameStillRestarts() async throws {
    let harness = Harness.withServeAction()
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    reportRunning(harness, in: first.id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    harness.model.setActionName("Serve", at: 0, in: harness.project)
    let pending = try #require(harness.model.pendingActionRestart)
    harness.model.answerActionRestart(pending, restarts: true)

    #expect(harness.engine.closed.contains(first.id))
    #expect(harness.model.actionSession(named: "Serve", in: harness.main.id)?.id != first.id)
  }

  @Test func pickingAnEndedActionAsksFirstWhereSomethingElseNowRunsInItsTab() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)
    reportRunning(harness, in: session.id)
    harness.model.noteCommandFinished(in: session.id, exitCode: 1)
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    #expect(harness.model.pendingActionRestart?.sessionID == session.id)
    #expect(!harness.engine.closed.contains(session.id))
  }

  private func trustFileActionSeed(_ harness: Harness) async throws {
    try #"{ "actions": [ { "name": "Seed", "command": "bin/rails db:seed" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.setTrustsSharedSettings(true, for: harness.project)
  }

  @Test func renamingOntoANameATabAlreadyHasLeavesTheRenamedTabNoActions() async throws {
    let harness = Harness.withServeAction()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    let seeding = try #require(harness.model.actionSession(named: "Seed", in: harness.main.id))
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let serving = try actionSession(harness)

    harness.model.setActionName("Seed", at: 0, in: harness.project)

    #expect(harness.model.workspace.session(serving.id)?.actionName == nil)
    #expect(harness.model.actionSession(named: "Seed", in: harness.main.id)?.id == seeding.id)
  }

  @Test func theRestartQuestionIsAskedAgainUnderTheActionsNewName() async throws {
    let harness = Harness.withServeAction()
    await harness.model.refreshSharedSettingsIfChanged()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    reportRunning(harness, in: try actionSession(harness).id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let asked = try #require(harness.model.pendingActionRestart)

    harness.model.setActionName("Serve", at: 0, in: harness.project)

    let askedAgain = try #require(harness.model.pendingActionRestart)
    #expect(askedAgain.title == t("project-action.restart-title", "Serve"))
    #expect(askedAgain.id != asked.id, "a new id puts the sheet up again with its new text")
    harness.model.answerActionRestart(asked, restarts: true)
    #expect(harness.model.pendingActionRestart == askedAgain, "the first sheet's answer is gone")
  }

  @Test func aTabMovedToAnotherWorktreeStopsBeingItsActionsThere() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let moving = try actionSession(harness)

    let tab = try #require(harness.model.workspace.tab(owning: moving.id))
    #expect(harness.store.moveTab(tab.id, toWorktree: harness.feature.id))

    #expect(harness.model.workspace.session(moving.id)?.actionName == nil)
    #expect(
      harness.model.actionSession(named: ProjectAction.serve.name, in: harness.feature.id) == nil
    )
  }

  @Test func aRestartAnsweredAfterItsTabMovedAwayRestartsNothing() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let first = try actionSession(harness)
    reportRunning(harness, in: first.id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let pending = try #require(harness.model.pendingActionRestart)
    let tab = try #require(harness.model.workspace.tab(owning: first.id))
    #expect(harness.store.moveTab(tab.id, toWorktree: harness.feature.id))

    harness.model.answerActionRestart(pending, restarts: true)

    #expect(!harness.engine.closed.contains(first.id))
  }

  @Test func aTabARenameLeavesNoActionsLeavesTheDockBadgeToo() async throws {
    let harness = Harness.withServeAction()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let serving = try actionSession(harness)
    harness.model.showAgentBoard()
    reportRunning(harness, in: serving.id)
    harness.model.noteCommandFinished(in: serving.id, exitCode: 1)
    #expect(harness.platform.badges.last == 1)

    harness.model.setActionName("Seed", at: 0, in: harness.project)

    #expect(harness.platform.badges.last == .some(nil))
  }

  @Test func renamingAnActionToItsOwnNameKeepsItsTab() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)

    #expect(
      harness.model.setActionName(" \(ProjectAction.serve.name) ", at: 0, in: harness.project)
        == ProjectAction.serve.name
    )

    #expect(harness.model.workspace.session(session.id)?.actionName == ProjectAction.serve.name)
  }

  @Test func anActionGivenANameNoActionHasNeverTakesOverATabLeftWithIt() async throws {
    let harness = Harness()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    let seeding = try #require(harness.model.actionSession(named: "Seed", in: harness.main.id))
    try "{}".write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )
    await harness.model.refreshSharedSettingsIfChanged()

    harness.model.addAction(to: harness.project)
    harness.model.setActionCommand("bin/seed", at: 0, in: harness.project)
    harness.model.setActionName("Seed", at: 0, in: harness.project)

    #expect(harness.model.workspace.session(seeding.id)?.actionName == nil)
    #expect(harness.model.actionSession(named: "Seed", in: harness.main.id) == nil)
  }

  @Test func pickingAnEndedActionAsksFirstWhereAnAgentWaitsAtItsPromptInItsTab() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    let session = try actionSession(harness)
    reportRunning(harness, in: session.id)
    harness.model.noteCommandFinished(in: session.id, exitCode: 0)
    harness.messageSource.send(
      SessionStateReport(state: .running, sessionID: session.id, agentID: "claude")
    )
    harness.messageSource.send(
      SessionStateReport(state: .done, sessionID: session.id, agentID: "claude")
    )

    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)

    #expect(harness.model.pendingActionRestart?.sessionID == session.id)
    #expect(!harness.engine.closed.contains(session.id))
  }

  @Test func theRestartQuestionGoesWhenItsTabStopsBeingTheActions() async throws {
    let harness = Harness.withServeAction()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    reportRunning(harness, in: try actionSession(harness).id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)

    harness.model.setActionName("Seed", at: 0, in: harness.project)

    #expect(harness.model.pendingActionRestart == nil)
  }

  @Test func theRestartQuestionGoesWithTheActionItAsksAbout() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    reportRunning(harness, in: try actionSession(harness).id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)

    harness.model.removeAction(at: 0, from: harness.project)

    #expect(harness.model.pendingActionRestart == nil)
  }

  @Test func theRestartQuestionGoesWhenItsActionsCommandIsCleared() throws {
    let harness = Harness.withServeAction()
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    reportRunning(harness, in: try actionSession(harness).id)
    harness.model.runAction(named: ProjectAction.serve.name, in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)

    harness.model.setActionCommand("", at: 0, in: harness.project)

    #expect(harness.model.pendingActionRestart == nil)
  }

  @Test func theRestartQuestionGoesWhenItsFilesTrustIsTakenBack() async throws {
    let harness = Harness()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    let seeding = try #require(harness.model.actionSession(named: "Seed", in: harness.main.id))
    reportRunning(harness, in: seeding.id)
    harness.model.runAction(named: "Seed", in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)

    harness.model.setTrustsSharedSettings(false, for: harness.project)

    #expect(harness.model.pendingActionRestart == nil)
  }

  @Test func theRestartQuestionGoesWhenTheFileIsReadWithoutItsAction() async throws {
    let harness = Harness()
    try await trustFileActionSeed(harness)
    harness.model.runAction(named: "Seed", in: harness.main)
    let seeding = try #require(harness.model.actionSession(named: "Seed", in: harness.main.id))
    reportRunning(harness, in: seeding.id)
    harness.model.runAction(named: "Seed", in: harness.main)
    #expect(harness.model.pendingActionRestart != nil)
    try #"{ "actions": [ { "name": "Migrate", "command": "bin/migrate" } ] }"#.write(
      to: SharedProjectSettings.file(in: harness.root),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.refreshSharedSettingsIfChanged()

    #expect(harness.model.pendingActionRestart == nil)
  }
}
