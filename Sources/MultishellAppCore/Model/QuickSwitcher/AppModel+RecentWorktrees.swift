import MultishellCore

extension AppModel {
  /// More than Recent lists, so a project's last worktree is still known
  /// after a run of others.
  private static var recentWorktreesKept: Int { 50 }

  /// Called from `select` alone, enough as launch selects nothing; see
  /// quick-switcher.md's settled list.
  func noteRecentWorktree(_ id: Worktree.ID) {
    recentWorktreeIDs.removeAll { $0 == id }
    recentWorktreeIDs.insert(id, at: 0)
    if recentWorktreeIDs.count > Self.recentWorktreesKept { recentWorktreeIDs.removeLast() }
  }
}
