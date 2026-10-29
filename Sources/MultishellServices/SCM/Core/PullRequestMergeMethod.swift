/// How a pull request lands on its base.
public enum PullRequestMergeMethod: Hashable, Sendable {
  case merge
  case rebase
  case squash

  /// The order GitHub's merge box lists them in.
  static let offered: [Self] = [.merge, .squash, .rebase]

  /// A rebase lands each commit with its own message, so takes none.
  public var takesMessage: Bool { self != .rebase }
}
