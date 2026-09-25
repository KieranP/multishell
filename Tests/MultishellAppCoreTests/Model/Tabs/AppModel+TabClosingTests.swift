import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabClosingTests {
  @Test func closingTheLastPaneClosesItsTabAndShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 2)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)
    #expect(h.engine.closed.count == 1)

    h.model.closeActivePane()
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)

    h.model.closeActivePane()  // nothing left: must not throw or select anything
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }

  @Test func splitThenCloseCollapsesBackToOnePane() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(tab.isSplit && h.model.liveTerminalCount == 2)

    h.model.closeActivePane()
    let after = h.model.workspace.tab(tab.id)!
    #expect(!after.isSplit)
    #expect(h.model.liveTerminalCount == 1)
  }

  /// The worktree rename drops its id when the row goes; the tab's had no
  /// equivalent, so a closed tab left one pointing at nothing.
  @Test func closingATabBeingRenamedTakesTheFieldWithIt() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.beginRenamingTab(tab.id)

    h.model.closeTab(tab.id)

    #expect(h.model.workspace.tab(tab.id) == nil)
    #expect(h.model.renamingTabID == nil)
  }

  /// A middle click closes the tab it landed on, which need not be the
  /// active one; the keystrokes only ever close what is on screen.
  @Test func aMiddleClickClosesTheTabItLandedOnActiveOrNot() {
    let h = Harness()
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let second = h.model.workspace.activeTab(in: h.main.id)!

    h.model.closeTab(first.id)

    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [second.id])
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == second.id, "the active one stays")
    #expect(h.engine.closed == [first.focusedSessionID], "its shell went with it")

    h.model.closeTab(UUID())
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "no such tab")
  }

  /// The same question Cmd+Shift+W asks, since a middle click on the wrong
  /// tab is at least as easy to make.
  @Test func aMiddleClickOnAWorkingAgentAsksFirst() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let working = h.model.workspace.activeTab(in: h.main.id)!
    h.model.select(h.feature)
    h.source.send(
      SessionStateReport(state: .running, sessionID: working.focusedSessionID, cwd: nil, pid: nil))

    h.model.closeTab(working.id)

    #expect(h.model.pendingClose == .tab(working.id))
    #expect(h.model.workspace.tab(working.id) != nil, "nothing closed until it is confirmed")

    h.model.confirmPendingClose()
    #expect(h.model.workspace.tab(working.id) == nil)
  }

  @Test func closingATabRunningAPlainCommandAsksNothing() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let building = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(
      SessionStateReport(
        state: .running, sessionID: building.focusedSessionID, command: "make", isShell: true))

    h.model.closeTab(building.id)

    #expect(h.model.pendingClose == nil)
    #expect(h.model.workspace.tab(building.id) == nil)
  }

  @Test func closingAWorkingPaneAsksFirstAndTheConfirmationCloses() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    h.model.closeActivePane()
    #expect(h.model.pendingClose == .pane(tab.focusedSessionID))
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1, "nothing closed yet")

    h.model.pendingClose = nil
    h.model.closeActiveTab()
    #expect(h.model.pendingClose == .tab(tab.id))

    h.model.confirmPendingClose()
    #expect(h.model.pendingClose == nil)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(h.model.liveTerminalCount == 0)
  }

  /// The question goes when its subject does, whichever way that happens, which is why the
  /// prune lives in the reconcile rather than beside a removal.
  @Test func aCloseWaitingOnAConfirmationGoesWithTheProjectItAskedAbout() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.source.send(SessionStateReport(state: .running, sessionID: tab.focusedSessionID))

    h.model.closeActiveTab()
    #expect(h.model.pendingClose == .tab(tab.id))

    h.model.removeProject(h.project)
    #expect(h.model.pendingClose == nil, "nothing left to ask about")
  }

  @Test func closingInAnotherWindowClosesThatWindowNotAPane() {
    let h = Harness()
    h.model.select(h.main)
    h.platform.workspaceWindowIsKey = false

    h.model.closeActivePane()
    h.model.closeActiveTab()

    #expect(h.platform.closedKeyWindows == 2)
    #expect(h.model.liveTerminalCount == 1, "the pane is still there")
  }
}
