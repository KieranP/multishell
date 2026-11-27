import MultishellCore

extension AppModel {
  public func isHidden(_ worktree: Worktree) -> Bool {
    workspace.isHidden(worktree)
  }

  /// The menus' Hide Worktree and Show Worktree. A row shown again may have
  /// gone unread in a collapsed section, so it is read now.
  public func setHidden(_ hidden: Bool, worktree: Worktree) {
    guard worktree.isHideable, isHidden(worktree) != hidden else { return }
    if hidden, renamingWorktreeID == worktree.id { renamingWorktreeID = nil }
    // A section the first hidden row makes starts collapsed, whatever the last one was.
    let isFirstHidden = !workspace.worktrees(of: worktree.projectID).contains(where: isHidden)
    if hidden, isFirstHidden { expandedHiddenSections.remove(worktree.projectID) }
    store.setHidden(hidden, worktree: worktree.id)
    guard !hidden else { return }
    Task { await refreshStatuses { $0.id == worktree.id } }
  }
}
