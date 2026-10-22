import MultishellCore

@testable import MultishellAppCore

extension AppModel {
  /// Selects `worktree` and opens `path` in a file tab last in its focused group,
  /// the reconcile handing it the keyboard as a click would.
  func openFileTab(_ path: String, in worktree: Worktree) -> FileTab? {
    select(worktree)
    let tab = store.openFileTab(path: path, in: worktree.id)
    reconcileSessions(takingFocus: true)
    return tab
  }
}
