import MultishellCore

extension AppModel {
  public func customName(of worktree: Worktree) -> String? {
    workspace.customName(of: worktree.id)
  }

  /// What a row or a header calls this worktree: the user's name where they
  /// gave one, else its branch.
  public func displayName(of worktree: Worktree) -> String {
    workspace.displayName(of: worktree)
  }
}
