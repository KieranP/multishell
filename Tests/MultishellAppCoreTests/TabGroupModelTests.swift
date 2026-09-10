import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// What the menu items and the drag targets do once the model has run them:
/// no shell restarted, the keyboard following the column that took the
/// focus, and a pane in a second column counting as on screen.
@Suite @MainActor
struct TabGroupModelTests {
  /// Two columns of the selected worktree, the second holding the tab that
  /// was active.
  private func twoColumns(_ h: Harness) -> (first: TabGroup, second: TabGroup) {
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let columns = h.model.workspace.groups(in: h.main.id)
    return (columns[0], columns[1])
  }

  @Test func moveTabToNewGroupDividesTheWorktreeWithoutRestartingAShell() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    let live = h.engine.openSessionIDs
    let moving = h.model.workspace.activeTab(in: h.main.id)!

    h.model.moveActiveTabToNewGroup()

    let columns = h.model.workspace.groups(in: h.main.id)
    #expect(columns.count == 2)
    #expect(h.model.workspace.tabs(in: columns[1].id).map(\.id) == [moving.id])
    #expect(h.model.focusedGroup?.id == columns[1].id)
    #expect(h.engine.openSessionIDs == live, "the shells kept running")
    #expect(h.engine.closed.isEmpty)
  }

  /// Both columns are on screen, so both their tabs are live; nothing is
  /// closed for being in the column that lost the focus.
  @Test func everyColumnsTabKeepsItsShell() {
    let h = Harness()
    _ = twoColumns(h)
    let shown = h.model.workspace.shownTabs(in: h.main.id)

    #expect(shown.count == 2)
    for id in shown.flatMap(\.sessionIDs) {
      #expect(h.model.liveSessions.contains(id))
      #expect(h.model.isShown(id), "a pane in the next column over is being looked at")
    }
  }

  @Test func focusingAColumnHandsItTheKeyboard() {
    let h = Harness()
    let columns = twoColumns(h)
    let firstsTab = h.model.workspace.activeTab(in: columns.first)!

    h.model.focusPreviousGroup()

    #expect(h.model.focusedGroup?.id == columns.first.id)
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == firstsTab.id)
    #expect(
      h.engine.focused.last == firstsTab.focusedSessionID,
      "the pane of the column that took the focus")

    h.model.focusNextGroup()
    #expect(h.model.focusedGroup?.id == columns.second.id, "and it wraps")
  }

  @Test func focusGoesNowhereWithOneColumn() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let before = h.model.workspace

    h.model.focusNextGroup()
    h.model.focusPreviousGroup()

    #expect(h.model.workspace == before)
  }

  /// Cmd+T opens in the focused column; a strip's own New Tab button names
  /// its column, so a click in one never opens a tab in another.
  @Test func aNewTabOpensInTheColumnThatAskedForIt() {
    let h = Harness()
    let columns = twoColumns(h)
    let before = h.model.workspace.tabs(in: columns.first.id).count

    h.model.newTab(in: columns.first.id)

    #expect(h.model.workspace.tabs(in: columns.first.id).count == before + 1)
    #expect(h.model.workspace.tabs(in: columns.second.id).count == 1, "the other column stands")
    #expect(h.model.focusedGroup?.id == columns.first.id, "opening a tab there is working in it")

    h.model.newTab()
    #expect(
      h.model.workspace.tabs(in: columns.first.id).count == before + 2,
      "the keystroke names no column and opens in the focused one")
  }

  /// Closing what a column shows leaves the column when it has other tabs
  /// and takes it away when it does not.
  @Test func aColumnLastsAsLongAsItHasATab() {
    let h = Harness()
    let columns = twoColumns(h)
    h.model.newTab(in: columns.second.id)
    #expect(h.model.workspace.tabs(in: columns.second.id).count == 2)

    h.model.closeActiveTab()
    #expect(h.model.workspace.groups(in: h.main.id).count == 2, "one tab left in it")

    h.model.closeActiveTab()
    #expect(h.model.workspace.groups(in: h.main.id).map(\.id) == [columns.first.id])
    #expect(h.model.focusedGroup?.id == columns.first.id)
  }

  /// Splitting acts on the focused column's active tab, wherever the other
  /// columns' panes are.
  @Test func splittingActsInsideTheFocusedColumn() {
    let h = Harness()
    let columns = twoColumns(h)
    h.model.focusGroup(columns.first.id)

    h.model.splitActivePane(.vertical)

    #expect(h.model.workspace.activeTab(in: columns.first)?.isSplit == true)
    #expect(h.model.workspace.activeTab(in: columns.second)?.isSplit == false)
  }

  /// A Done state in another column clears when it lands, because that
  /// pane is on screen; `SessionStates` is asked with `isShown`.
  @Test func aFinishedCommandInAnotherColumnIsSeenAtOnce() {
    let h = Harness()
    let columns = twoColumns(h)
    let watched = h.model.workspace.activeTab(in: columns.first)!.focusedSessionID

    h.source.send(SessionStateReport(state: .done, sessionID: watched, cwd: nil, pid: nil))

    #expect(
      h.model.sessionStates[.session(watched)] == nil,
      "the user is looking at it, so there is nothing to tell them")
  }

  /// Dragging a tab along its own strip moves it as the pointer passes each
  /// neighbour, so the tabs make room instead of jumping on release.
  @Test func aTabShufflesAlongItsOwnStripAsItIsDragged() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)
    let (first, last) = (order[0], order[order.count - 1])

    h.model.shuffleTab(last.id, .before, past: first.id)

    #expect(h.model.workspace.tabs(in: h.main.id).first?.id == last.id)
    #expect(
      h.model.workspace.activeTab(in: h.main.id)?.id == last.id,
      "reordering does not change which tab is showing")
  }

  /// Repeating the move the pointer is already sitting on must not write the
  /// workspace again: this runs on every few pixels of a drag.
  @Test func shufflingToWhereTheTabAlreadySitsChangesNothing() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)
    let before = h.model.workspace

    h.model.shuffleTab(order[1].id, .after, past: order[0].id)
    h.model.shuffleTab(order[0].id, .before, past: order[1].id)
    h.model.shuffleTab(order[0].id, .after, past: order[0].id)

    #expect(h.model.workspace == before)
  }

  /// The drop at the end of a shuffle lands on the move the shuffle has
  /// already made. Repeating it would leave the strip identical and cost a
  /// save and a re-render, so it writes nothing at all.
  @Test func aDropOnAMoveAlreadyMadeWritesNothing() {
    let h = Harness()
    h.model.select(h.main)
    h.model.newTab()
    let order = h.model.workspace.tabs(in: h.main.id)

    h.model.shuffleTab(order[1].id, .before, past: order[0].id)
    let shuffled = h.model.workspace

    // What the release does, with the pointer still where it was.
    h.model.moveTab(order[1].id, .before, order[0].id)

    #expect(h.model.workspace == shuffled)
  }

  /// A tab crossing into another column waits for the drop. Moving it live
  /// would close the column it left while the drag is still going, taking
  /// the layout out from under the pointer.
  @Test func aTabDoesNotShuffleIntoAnotherColumn() {
    let h = Harness()
    let columns = twoColumns(h)
    let staying = h.model.workspace.activeTab(in: columns.first)!
    let moving = h.model.workspace.activeTab(in: columns.second)!

    h.model.shuffleTab(moving.id, .before, past: staying.id)

    #expect(h.model.workspace.tab(moving.id)?.groupID == columns.second.id)
    #expect(
      !h.model.workspace.tabs(in: columns.first.id).contains { $0.id == moving.id },
      "it stays out of the column it was dragged over")
  }

  @Test func aTabDraggedToAnotherWorktreeLeavesNoColumnBehind() {
    let h = Harness()
    // Selecting opens the worktree's first tab, and that one tab is the
    // whole of its only column.
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    #expect(h.model.workspace.tabs(in: h.main.id).count == 1)

    #expect(h.model.moveTab(tab.id, to: h.feature.id))

    #expect(h.model.workspace.groups(in: h.main.id).isEmpty)
    #expect(h.model.workspace.groups(in: h.feature.id).count == 1)
    #expect(h.model.workspace.activeTab(in: h.feature.id)?.id == tab.id)
  }
}
