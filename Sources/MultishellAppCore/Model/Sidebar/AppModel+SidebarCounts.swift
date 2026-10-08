import MultishellCore

extension AppModel {
  /// The sidebar's foot: how many worktrees and terminals the workspace holds.
  public var sidebarCountsText: String {
    t(
      "sidebar.counts", t("count.worktrees", workspace.worktrees.count),
      t("count.terminals", workspace.sessions.count))
  }
}
