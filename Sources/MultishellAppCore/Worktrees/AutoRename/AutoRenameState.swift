/// Where a worktree's Auto Rename stands. None at all once it has named the
/// row, or once its failure is cleared.
public enum AutoRenameState: Hashable, Sendable {
  /// Why, as the row's warning and the banner word it.
  case failed(String)
  case running

  public var failureMessage: String? {
    guard case .failed(let message) = self else { return nil }
    return message
  }
}
