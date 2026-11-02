extension Workspace {
  /// Whether the sidebar lists this worktree in its project's Hidden section.
  /// A main worktree a hand-edited file marks is not.
  public func isHidden(_ worktree: Worktree) -> Bool {
    worktree.isHideable && hiddenWorktreeIDs.contains(worktree.id)
  }
}
