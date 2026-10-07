import MultishellCore

extension AppModel {
  /// The worktree in view when a shell may start in it. `nil` otherwise,
  /// the missing-directory alert already raised.
  func requireWorktreeForShell() -> Worktree? {
    worktreeInView.flatMap { requireShellReady($0) ? $0 : nil }
  }

  /// Whether a shell may start in `worktree`: no create or remove running or
  /// failed there, and its directory present. Every way of starting one asks.
  func requireShellReady(_ worktree: Worktree) -> Bool {
    !isBusy(worktree.id) && requireDirectory(of: worktree)
  }

  /// Checked before anything that starts a shell, a missing directory being
  /// refused. Named for the demand, since it raises the alert itself.
  func requireDirectory(of worktree: Worktree) -> Bool {
    switch directoryProbe.probe(worktree.path.path) {
    case .present:
      noteDirectoryPresent(of: worktree.id)
      return true
    case .missing: presentedError = .worktreeDirectoryMissing(worktree.path.path)
    case .unanswered: presentedError = .worktreeDirectoryUnanswered(worktree.path.path)
    }
    return false
  }
}
