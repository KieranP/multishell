import Foundation
import MultishellCore

/// A worktree's terminal area is one or more columns of tabs. All layout, so
/// none of it asks whether a shell could start.
extension AppModel {
  /// The column the keystrokes go to, which is what the menu items and the
  /// tab-strip chrome are drawn from.
  public var focusedGroup: TabGroup? {
    worktreeInView.flatMap { workspace.focusedGroup(in: $0.id) }
  }

  /// A click anywhere in a column's strip. The pane keeps whatever focus it
  /// had inside the tab, and the reconcile hands the keyboard to it.
  public func focusGroup(_ id: TabGroup.ID) {
    store.focusGroup(id)
    reconcileSessions(takingFocus: true)
  }

  public func focusNextGroup() { focusGroup(.after) }
  public func focusPreviousGroup() { focusGroup(.before) }

  /// Wraps at either end, the way `selectTab` walks a strip.
  private func focusGroup(_ direction: TerminalTab.Placement) {
    guard
      let worktree = worktreeInView?.id,
      let current = workspace.focusedGroup(in: worktree),
      let next = workspace.groups(in: worktree).neighbour(of: current.id, direction)
    else { return }
    focusGroup(next.id)
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
    reconcileSessions(takingFocus: true)
    return true
  }

  /// A tab dropped on a column's strip clear of its tabs: it lands last
  /// there. A drop on a tab goes through `moveTab(_:_:_:)` instead.
  @discardableResult
  public func moveTab(_ id: TerminalTab.ID, toEndOf group: TabGroup.ID) -> Bool {
    guard store.moveTab(id, toEndOf: group) else { return false }
    reconcileSessions(takingFocus: true)
    return true
  }

  /// Written back as the divider between two columns is dragged.
  public func setGroupWeights(_ weights: [Double], in worktree: Worktree.ID) {
    store.setGroupWeights(weights, in: worktree)
  }

  /// A tab dragged along its own strip, moved as the pointer passes each
  /// neighbour. Only inside one column, and no reconcile; see tabs-and-columns.md.
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

  public func beginTabDrag(_ id: TerminalTab.ID) {
    tabDragReleaseWatch?.cancel()
    tabDragReleaseWatch = nil
    let strip = workspace.tab(id).map { workspace.tabs(in: $0.groupID).map(\.id) } ?? []
    guard let index = strip.firstIndex(of: id) else { return tabDrag.begin(id) }
    tabDrag.begin(
      id,
      home: TabDragState.Home(
        earlier: strip[..<index].reversed(), later: Array(strip[(index + 1)...])))
  }

  /// A drag no drop took, ended with its session, puts back what its shuffle
  /// moved. Only while `id` is in the air: a drop that took it ended it first.
  public func endAbandonedTabDrag(_ id: TerminalTab.ID) {
    guard tabDrag.tabID == id else { return }
    let home = tabDrag.home
    tabDrag.end()
    putBack(id, home: home)
  }

  /// The dragged tab's button left the screen. A closed tab's drag ends now. A
  /// rebuilt one's ends with the button up, its session's end reaching no one.
  public func tabDragSourceLeft(_ id: TerminalTab.ID, isPressed: @escaping @MainActor () -> Bool) {
    guard tabDrag.tabID == id else { return }
    guard workspace.tab(id) != nil else { return endAbandonedTabDrag(id) }
    tabDragReleaseWatch?.cancel()
    tabDragReleaseWatch = Task { [weak self] in
      await DragRelease.wait(isPressed: isPressed)
      guard !Task.isCancelled else { return }
      self?.endAbandonedTabDrag(id)
    }
  }

  /// Whether a release on this worktree's row would move the dragged tab, so
  /// the row lights only when it would. A missing directory lights, for its alert.
  public func worktreeRowTakesDraggedTab(_ worktreeID: Worktree.ID) -> Bool {
    guard let id = tabDrag.tabID, let tab = workspace.tab(id) else { return false }
    return tab.worktreeID != worktreeID && !isBusy(tab.worktreeID) && !isBusy(worktreeID)
      && workspace.worktree(worktreeID) != nil
  }

  /// A release over a drop target, `false` with no tab in the air or on its own
  /// worktree's row. The move runs a turn later; a refused one puts it back.
  @discardableResult
  public func dropDraggedTab(on drop: TabDrop) -> Bool {
    guard let id = tabDrag.tabID else { return false }
    if case .worktree(let worktreeID) = drop, !worktreeRowTakesDraggedTab(worktreeID) {
      return false
    }
    let home = tabDrag.home
    tabDrag.end()
    // A turn later, so the drag is over before the tab leaves the strip.
    Task { @MainActor in
      if !move(id, droppedOn: drop) { putBack(id, home: home) }
    }
    return true
  }

  /// `false` where the drop refused the tab, which then goes back. Its own
  /// strip takes it where the shuffle left it; its own area lights nothing.
  private func move(_ id: TerminalTab.ID, droppedOn drop: TabDrop) -> Bool {
    switch drop {
    case .tab(let anchor, let placement):
      return moveTab(id, placement, anchor)
    case .strip(let group):
      return workspace.tab(id)?.groupID == group || moveTab(id, toEndOf: group)
    case .area(let group):
      return moveTab(id, toEndOf: group)
    case .band(let band):
      return moveTab(id, band.placement, toNewGroupOf: band.groupID)
    case .worktree(let worktreeID):
      // A missing directory raises its alert; a busy worktree refuses quietly.
      return moveTab(id, to: worktreeID)
    }
  }

  /// Puts `id` back between the neighbours it had as the drag began, skipping
  /// any that have left its column since.
  private func putBack(_ id: TerminalTab.ID, home: TabDragState.Home?) {
    guard let home, let groupID = workspace.tab(id)?.groupID else { return }
    let isBeside = { (other: TerminalTab.ID) in self.workspace.tab(other)?.groupID == groupID }
    if let next = home.later.first(where: isBeside) {
      shuffleTab(id, .before, past: next)
    } else if let previous = home.earlier.first(where: isBeside) {
      shuffleTab(id, .after, past: previous)
    }
  }
}
