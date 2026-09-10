import Foundation
import MultishellCore

// MARK: - Tab groups

/// A worktree's terminal area is one or more columns of tabs; see `TabGroup`.
/// Everything here is layout, so unlike opening a tab none of it asks
/// whether a shell could start: no directory is read and no process begins.
extension AppModel {
  /// The column the keystrokes go to, which is what the menu items and the
  /// tab-strip chrome are drawn from.
  public var focusedGroup: TabGroup? {
    workspace.selectedWorktreeID.flatMap { workspace.focusedGroup(in: $0) }
  }

  /// A click anywhere in a column's strip. The pane keeps whatever focus it
  /// had inside the tab, and `sync` hands the keyboard to it.
  public func focusGroup(_ id: TabGroup.ID) {
    store.focusGroup(id)
    sync()
  }

  public func focusNextGroup() { focusGroup(offset: 1) }
  public func focusPreviousGroup() { focusGroup(offset: -1) }

  /// Wraps at either end, the way `selectTab` walks a strip.
  private func focusGroup(offset: Int) {
    guard
      let worktree = workspace.selectedWorktreeID,
      let current = workspace.focusedGroup(in: worktree)
    else { return }
    let columns = workspace.groups(in: worktree)
    guard columns.count > 1, let index = columns.firstIndex(where: { $0.id == current.id }) else {
      return
    }
    focusGroup(columns[(index + offset + columns.count) % columns.count].id)
  }

  /// Move Tab to New Group: the tab in front of the user gets a column of
  /// its own, to the right of the column it was in.
  public func moveActiveTabToNewGroup() {
    guard let group = focusedGroup, let tab = workspace.activeTab(in: group) else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// A tab dropped on the band down one edge of a column's terminal area,
  /// or the menu item above. `false` when nothing moved, so a drag springs
  /// back rather than looking like it did something; `WorkspaceStore` has
  /// the cases.
  @discardableResult
  public func moveTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, toNewGroupOf group: TabGroup.ID
  ) -> Bool {
    guard store.moveTabToNewGroup(id, placement, of: group) != nil else { return false }
    sync()
    return true
  }

  /// A tab dropped on a column's strip clear of its tabs: it lands last
  /// there. A drop on a tab goes through `moveTab(_:_:_:)` instead.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, toEndOf group: TabGroup.ID) -> Bool {
    guard store.moveTab(id, toEndOf: group) else { return false }
    sync()
    return true
  }

  /// Written back as the divider between two columns is dragged.
  public func setGroupWeights(_ weights: [Double], in worktree: Worktree.ID) {
    store.setGroupWeights(weights, in: worktree)
  }

  /// A tab dragged along its own strip, moved as the pointer passes each of
  /// its neighbours: the tabs slide out of the way, and the tab being
  /// dragged is where it will land rather than waiting to jump there.
  ///
  /// Only inside one column. A tab crossing into another column, or onto
  /// another worktree's row, waits for the drop: a column emptied by the
  /// move closes, and closing one under the pointer takes the layout out
  /// from under the drag that is still going on.
  ///
  /// No `sync` and no session touched — this is one column's order and
  /// nothing else, and it runs on every few pixels of a drag.
  public func shuffleTab(
    _ id: TerminalTab.ID, _ placement: TerminalTab.Placement, past anchor: TerminalTab.ID
  ) {
    guard
      let moving = workspace.tab(id), let target = workspace.tab(anchor),
      moving.groupID == target.groupID
    else { return }
    // `moveTab` is what drops the moves that would change nothing, which is
    // most of the ones a drag asks for.
    moveTab(id, placement, anchor)
  }
}
