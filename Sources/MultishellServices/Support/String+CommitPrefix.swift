extension String {
  /// git's own shortest abbreviation; anything shorter names too many commits.
  private static let shortestCommitPrefix = 7

  /// The commit as git abbreviates it.
  public var abbreviatedCommit: String { String(prefix(Self.shortestCommitPrefix)) }

  /// Whether this commit hash and `other` name one commit, where a provider or
  /// host gives a prefix of it.
  public func namesSameCommit(as other: String) -> Bool {
    if self == other { return true }
    guard Swift.min(count, other.count) >= Self.shortestCommitPrefix else { return false }
    return hasPrefix(other) || other.hasPrefix(self)
  }
}
