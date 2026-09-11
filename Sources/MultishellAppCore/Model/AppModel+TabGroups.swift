import Foundation
import MultishellCore

// MARK: - Tab groups

/// A worktree's terminal area is one or more columns of tabs. All layout, so
/// none of it asks whether a shell could start.
extension AppModel {
  /// The column the keystrokes go to, which is what the menu items and the
  /// tab-strip chrome are drawn from.
  public var focusedGroup: TabGroup? {
    worktreeInView.flatMap { workspace.focusedGroup(in: $0.id) }
  }

  /// A click anywhere in a column's strip. The pane keeps whatever focus it
  /// had inside the tab, and `sync` hands the keyboard to it.
  public func focusGroup(_ id: TabGroup.ID) {
    store.focusGroup(id)
    sync()
  }

  public func focusNextGroup() { focusGroup(.after) }
  public func focusPreviousGroup() { focusGroup(.before) }

  /// Wraps at either end, the way `selectTab` walks a strip, and takes its
  /// backwards step forwards for the same reason `Workspace.neighbour` does.
  private func focusGroup(_ direction: TerminalTab.Placement) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.focusedGroup(in: worktree)
    else { return }
    let columns = workspace.groups(in: worktree)
    guard columns.count > 1, let index = columns.firstIndex(where: { $0.id == current.id }) else {
      return
    }
    let step = direction == .after ? 1 : columns.count - 1
    focusGroup(columns[(index + step) % columns.count].id)
  }

  /// Move Tab to New Group: the tab in front of the user gets a column of
  /// its own, to the right of the column it was in.
  public func moveActiveTabToNewGroup() {
    guard let group = focusedGroup, let tab = workspace.activeTab(in: group) else { return }
    moveTab(tab.id, .after, toNewGroupOf: group.id)
  }

  /// A tab dropped on the band down a column's edge, or the menu item above.
  /// `false` when nothing moved, so the drag springs back.
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

  /// A tab dragged along its own strip, moved as the pointer passes each
  /// neighbour. Only inside one column, and no `sync`; see tabs-and-columns.md.
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
