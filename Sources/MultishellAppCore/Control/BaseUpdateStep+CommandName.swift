import MultishellCore

/// `worktrees show`'s word for what runs on a worktree's base.
extension BaseUpdateStep {
  var commandName: String {
    switch self {
    case .aborting: "aborting"
    case .checking: "checking"
    case .fetching: "fetching"
    case .updating(.merge): "merging"
    case .updating(.rebase): "rebasing"
    }
  }
}
