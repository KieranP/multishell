import MultishellCore

/// The All changes tab opened from the Changes page or the command line; see
/// Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// The worktree's All changes tab, made or turned to, taking the keyboard.
  @discardableResult
  public func openAllChangesTab(in id: Worktree.ID) -> AllChangesTab? {
    guard workspace.worktree(id) != nil, let tab = store.openAllChangesTab(in: id) else {
      return nil
    }
    reconcileSessions(takingFocus: worktreeIDInView == id)
    return tab
  }
}
