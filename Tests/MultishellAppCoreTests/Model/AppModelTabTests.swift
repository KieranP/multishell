import Foundation
import MultishellCore
import MultishellProcess
import TestScratch
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabTests {
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

  /// The drop activates the tab in the column it lands in, so the tab that
  /// was showing there goes behind it and must not keep the keyboard.
  @Test func aTabDroppedOnAnotherColumnsTabTakesTheKeyboardWithIt() throws {
    let h = Harness()
    h.model.select(h.main)
    let a = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.newTab()
    let b = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.moveActiveTabToNewGroup()
    h.model.activate(try #require(h.model.workspace.tab(a.id)))
    #expect(h.model.workspace.group(of: a.id)?.id != h.model.workspace.group(of: b.id)?.id)
    h.engine.focused.removeAll()

    h.model.moveTab(b.id, .before, a.id)

    #expect(h.model.workspace.group(of: b.id)?.id == h.model.workspace.group(of: a.id)?.id)
    #expect(
      h.engine.focused.last == h.model.workspace.tab(b.id)?.focusedSessionID,
      "b is what the column shows now; a is behind it")
  }

  @Test func focusingTheActivePaneHandsTheKeyboardToTheActiveTabsFocusedSession() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.engine.focused.removeAll()

    h.model.focusActivePane()

    #expect(h.engine.focused == [tab.focusedSessionID])
  }

  @Test func focusingTheActivePaneDoesNothingWhileTheBoardCoversThePanes() {
    let h = Harness()
    h.model.select(h.main)
    h.model.showAgentBoard()
    h.engine.focused.removeAll()

    h.model.focusActivePane()

    #expect(h.engine.focused.isEmpty)
  }

  /// The field commits on losing focus and Escape removes it, so a commit can arrive after
  /// the edit was abandoned. The worktree rename always guarded this; the tab's did not.
  @Test func escapeOnATabsNameFieldIsNotUndoneByTheCommitLosingFocus() throws {
    let h = Harness()
    h.model.select(h.main)
    let a = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.newTab()
    let b = try #require(h.model.workspace.activeTab(in: h.main.id))

    h.model.beginRenamingTab(a.id)
    h.model.cancelRenamingTab()
    h.model.commitTabRename(of: a.id, to: "scratch")
    #expect(h.model.workspace.tab(a.id)?.customTitle == nil, "Escape kept the name it had")

    // A second field opening must not be closed by the first one's late blur.
    h.model.beginRenamingTab(a.id)
    h.model.beginRenamingTab(b.id)
    h.model.commitTabRename(of: a.id, to: "late")
    #expect(h.model.workspace.tab(a.id)?.customTitle == nil)
    #expect(h.model.renamingTabID == b.id, "b is still the one being typed into")

    h.model.commitTabRename(of: b.id, to: "build")
    #expect(h.model.workspace.tab(b.id)?.customTitle == "build")
    #expect(h.model.renamingTabID == nil)
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

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, .before, a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])

    h.model.moveTab(b.id, .after, a.id)
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [a.id, b.id])
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

  @Test func aTabDraggedOntoAnotherWorktreeGoesThereWithItsShells() {
    let h = Harness()
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    h.model.splitActivePane(.vertical)
    let panes = Set(h.model.workspace.tab(tab.id)!.sessionIDs)

    #expect(h.model.moveTab(tab.id, to: h.feature.id))

    #expect(h.model.workspace.selectedWorktreeID == h.feature.id)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
    #expect(h.model.workspace.tabs(in: h.main.id).isEmpty)
    #expect(panes.isSubset(of: h.engine.openSessionIDs), "the shells kept running")
    #expect(h.engine.closed.isEmpty)
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1, "no second tab was opened")
  }

  @Test func aTabIsNotDraggedIntoAWorktreeThatCannotTakeIt() {
    let h = Harness()
    let gone = Worktree(
      path: URL(fileURLWithPath: "/repos/gone"), projectID: h.project.id, head: "c",
      branch: "gone")
    h.store.replaceWorktrees([h.main, h.feature, gone], forProject: h.project.id)
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!

    h.model.worktreeOperations.begin(.removingWorktree, on: h.feature.id)
    #expect(h.model.moveTab(tab.id, to: h.feature.id) == false, "a worktree on its way out")
    h.model.worktreeOperations.clear(h.feature.id)

    // The other end of the same rule: a tab dragged clear of a removal
    // would be the one thing still running in a trashed directory.
    h.model.worktreeOperations.begin(.removingWorktree, on: h.main.id)
    #expect(h.model.moveTab(tab.id, to: h.feature.id) == false, "dragged out of a removal")
    h.model.worktreeOperations.clear(h.main.id)

    h.model.presentedError = nil
    #expect(h.model.moveTab(tab.id, to: gone.id) == false)
    #expect(h.model.presentedError?.title == "Worktree directory is missing")
    #expect(h.model.moveTab(tab.id, to: h.main.id) == false, "already there")

    #expect(h.model.workspace.tab(tab.id)?.worktreeID == h.main.id)
    #expect(h.model.workspace.selectedWorktreeID == h.main.id)
  }
}
