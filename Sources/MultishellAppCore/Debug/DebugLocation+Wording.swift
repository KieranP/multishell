import MultishellCore

extension DebugLocation {
  /// "project / worktree", or the directory's name where it is in none.
  public var title: String {
    projectName.map { t("debug.location", $0, worktreeName) } ?? worktreeName
  }
}
