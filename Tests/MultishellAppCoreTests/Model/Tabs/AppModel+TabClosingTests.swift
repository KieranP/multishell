import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabClosingTests {
  @Test func closingTheLastPaneClosesItsTabAndShell() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 2)

    harness.model.closeActivePane()
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1)
    #expect(harness.engine.closed.count == 1)

    harness.model.closeActivePane()
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(harness.model.liveTerminalCount == 0)

    harness.model.closeActivePane()
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
  }

  @Test func splitThenCloseCollapsesBackToOnePane() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    #expect(tab.isSplit && harness.model.liveTerminalCount == 2)

    harness.model.closeActivePane()
    let after = harness.model.workspace.tab(tab.id)!
    #expect(!after.isSplit)
    #expect(harness.model.liveTerminalCount == 1)
  }

  /// The worktree rename drops its id when the row goes; the tab's had no
  /// equivalent, so a closed tab left one pointing at nothing.
  @Test func closingATabBeingRenamedTakesTheFieldWithIt() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.beginRenamingTab(tab.id)

    harness.model.closeTab(tab.id)

    #expect(harness.model.workspace.tab(tab.id) == nil)
    #expect(harness.model.renamingTabID == nil)
  }

  /// The keystrokes only ever close what is on screen; a click can reach any
  /// tab.
  @Test func aMiddleClickClosesTheTabItLandedOnThoughAnotherIsActive() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.model.closeTab(first.id)

    #expect(harness.model.workspace.tabs(in: harness.main.id).map(\.id) == [second.id])
    #expect(
      harness.model.workspace.activeTab(in: harness.main.id)?.id == second.id,
      "the active one stays",
    )
    #expect(harness.engine.closed == [first.focusedSessionID], "its shell went with it")

    harness.model.closeTab(UUID())
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1, "no such tab")
  }

  /// The same question Cmd+Shift+W asks, since a middle click on the wrong
  /// tab is at least as easy to make.
  @Test func aMiddleClickOnAWorkingAgentAsksFirst() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let working = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.model.select(harness.feature)
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: working.focusedSessionID,
        workingDirectory: nil,
        pid: nil,
      )
    )

    harness.model.closeTab(working.id)

    #expect(harness.model.pendingClose == .tab(working.id))
    #expect(harness.model.workspace.tab(working.id) != nil, "nothing closed until it is confirmed")

    harness.model.answerClose(.tab(working.id), confirmed: true)
    #expect(harness.model.workspace.tab(working.id) == nil)
  }

  @Test func cancellingAPendingCloseClosesNothingAndAsksNoMore() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))
    harness.model.closeActiveTab()

    harness.model.answerClose(.tab(tab.id), confirmed: false)

    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tab(tab.id) != nil)
  }

  @Test func closingATabRunningAPlainCommandAsksNothing() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    let building = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(
      SessionStateReport(
        state: .running,
        sessionID: building.focusedSessionID,
        command: "make",
        isFromShellIntegration: true,
      )
    )

    harness.model.closeTab(building.id)

    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tab(building.id) == nil)
  }

  @Test func closingAWorkingPaneAsksFirstAndTheConfirmationClosesIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.model.splitActivePane(.horizontal)
    let pane = harness.model.workspace.tab(tab.id)!.focusedSessionID
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: pane))

    harness.model.closeActivePane()
    #expect(harness.model.pendingClose == .pane(pane))
    #expect(harness.model.workspace.session(pane) != nil, "nothing closed yet")

    harness.model.answerClose(.pane(pane), confirmed: true)
    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.session(pane) == nil)
    #expect(harness.model.workspace.tab(tab.id) != nil, "only the pane went")
  }

  @Test func closingAWorkingTabAsksFirstAndTheConfirmationClosesEveryPane() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    harness.model.closeActiveTab()
    #expect(harness.model.pendingClose == .tab(tab.id))

    harness.model.answerClose(.tab(tab.id), confirmed: true)
    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(harness.model.liveTerminalCount == 0)
  }

  @Test func answeringOneCloseDoesNotPerformAnotherThatReplacedIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    let first = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.model.newTab()
    let second = harness.model.workspace.activeTab(in: harness.main.id)!
    for tab in [first, second] {
      harness.stateSource.send(
        SessionStateReport(state: .running, sessionID: tab.focusedSessionID)
      )
    }

    harness.model.closeActivePane()
    #expect(harness.model.pendingClose == .pane(second.focusedSessionID))
    harness.model.closeTab(first.id)
    #expect(harness.model.pendingClose == .tab(first.id))

    harness.model.answerClose(.pane(second.focusedSessionID), confirmed: true)

    #expect(harness.model.workspace.tab(first.id) != nil, "nobody confirmed closing this tab")
    #expect(harness.model.pendingClose == .tab(first.id), "and its question still stands")
  }

  @Test func aCloseTheEngineIsAskedForOnAWorkingPaneAsksFirst() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    harness.engine.delegate?.terminalHost(harness.engine, didAskToClose: tab.focusedSessionID)

    #expect(harness.model.pendingClose == .pane(tab.focusedSessionID))
    #expect(harness.model.workspace.tabs(in: harness.main.id).count == 1, "nothing closed yet")
  }

  @Test func aCloseTheEngineIsAskedForOnAnIdlePaneClosesIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!

    harness.engine.delegate?.terminalHost(harness.engine, didAskToClose: tab.focusedSessionID)

    #expect(harness.model.pendingClose == nil)
    #expect(harness.model.workspace.tabs(in: harness.main.id).isEmpty)
    #expect(harness.model.liveTerminalCount == 0)
  }

  /// The question goes when its subject does, whichever way that happens, which is why the
  /// prune lives in the reconcile rather than beside a removal.
  @Test func aCloseWaitingOnAConfirmationGoesWithTheProjectItAskedAbout() {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.stateSource.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    harness.model.closeActiveTab()
    #expect(harness.model.pendingClose == .tab(tab.id))

    harness.model.removeProject(harness.project)
    #expect(harness.model.pendingClose == nil, "nothing left to ask about")
  }

  @Test func closingInAnotherWindowClosesThatWindowNotAPane() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.platform.workspaceWindowIsKey = false

    harness.model.closeActivePane()
    harness.model.closeActiveTab()

    #expect(harness.platform.closedKeyWindows == 2)
    #expect(harness.model.liveTerminalCount == 1, "the pane is still there")
  }
}
