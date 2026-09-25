import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabsTests {

  /// The drop activates the tab in the group it lands in, so the tab that
  /// was showing there goes behind it and must not keep the keyboard.
  @Test func aTabDroppedOnAnotherGroupsTabTakesTheKeyboardWithIt() throws {
    let h = Harness()
    h.model.select(h.main)
    let a = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.newTab()
    let b = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.moveActiveTabToNewGroup()
    h.model.activate(try #require(h.model.workspace.tab(a.id)))
    #expect(h.model.workspace.tab(a.id)?.groupID != h.model.workspace.tab(b.id)?.groupID)
    h.engine.focused.removeAll()

    h.model.moveTab(b.id, .before, anchor: a.id)

    #expect(h.model.workspace.tab(b.id)?.groupID == h.model.workspace.tab(a.id)?.groupID)
    #expect(
      h.engine.focused.last == h.model.workspace.tab(b.id)?.focusedSessionID,
      "b is what the group shows now; a is behind it")
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

  @Test func useShellTitleWithTheNameFieldOpenIsNotUndoneByTheCommitLosingFocus() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.renameTab(tab.id, to: "build")
    h.model.beginRenamingTab(tab.id)

    h.model.renameTab(tab.id, to: nil)
    h.model.commitTabRename(of: tab.id, to: "build")

    #expect(h.model.workspace.tab(tab.id)?.customTitle == nil)
    #expect(h.model.renamingTabID == nil)
  }

  @Test func tabRenamesAndReordersReachTheStore() {
    let h = Harness()
    h.model.select(h.main)
    let a = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()
    let b = h.model.workspace.activeTab(in: h.main.id)!

    h.model.renameTab(a.id, to: "build")
    h.model.moveTab(b.id, .before, anchor: a.id)

    #expect(h.model.workspace.title(of: h.model.workspace.tab(a.id)!) == "build")
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [b.id, a.id])

    h.model.moveTab(b.id, .after, anchor: a.id)
    #expect(h.model.workspace.tabs(in: h.main.id).map(\.id) == [a.id, b.id])
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

  @Test func theFocusRingShowsOnlyWithAnotherPaneOnScreen() throws {
    let h = Harness()
    h.model.select(h.main, openingFirstTab: .never)
    h.model.newTab()
    let lone = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(!h.model.showsFocusRing(in: lone))

    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let beside = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(h.model.workspace.groups(in: h.main.id).count == 2)
    #expect(h.model.showsFocusRing(in: beside))
  }

  @Test func aSplitTabWearsTheRingOnItsOwn() throws {
    let h = Harness()
    h.model.select(h.main, openingFirstTab: .never)
    h.model.newTab()
    h.model.splitActivePane(.horizontal)

    let split = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(split.isSplit)
    #expect(h.model.showsFocusRing(in: split))
  }
}
