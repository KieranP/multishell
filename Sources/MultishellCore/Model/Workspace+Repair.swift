import Foundation

extension Workspace {
  /// Restores the invariants the store maintains between its collections
  /// after state comes off disk, where a crash mid-save, a hand edit or a bug
  /// in an earlier build can leave them broken.
  ///
  /// A session in no tab would otherwise be given a live shell that nothing
  /// displays and nothing can close; a tab whose active entry is missing
  /// hides the whole tab strip.
  public mutating func repairReferences() {
    let projectIDs = Set(projects.map(\.id))
    worktrees.removeAll { !projectIDs.contains($0.projectID) }
    let worktreeIDs = Set(worktrees.map(\.id))
    tabs.removeAll { !worktreeIDs.contains($0.worktreeID) }

    let sessionIDs = Set(sessions.map(\.id))
    tabs = tabs.compactMap { tab in
      var repaired = tab
      for missing in tab.sessionIDs where !sessionIDs.contains(missing) {
        guard let remaining = repaired.root.removing(missing) else { return nil }
        repaired.root = remaining
      }
      guard let first = repaired.root.sessionIDs.first else { return nil }
      if !repaired.root.contains(repaired.focusedSessionID) {
        repaired.focusedSessionID = first
      }
      return repaired
    }

    let owned = Set(tabs.flatMap(\.sessionIDs))
    sessions.removeAll { !owned.contains($0.id) }

    for (worktreeID, tabID) in activeTabByWorktree where tab(tabID)?.worktreeID != worktreeID {
      activeTabByWorktree[worktreeID] = tabs(in: worktreeID).last?.id
    }

    if let selected = selectedWorktreeID, !worktreeIDs.contains(selected) {
      selectedWorktreeID = nil
    }
  }
}
