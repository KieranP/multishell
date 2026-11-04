import MultishellServices

extension PullRequestState {
  /// Merged or closed: nothing about it moves any more without a reopen.
  var isSettled: Bool {
    switch self {
    case .closed, .merged: true
    case .draft, .open: false
    }
  }
}
