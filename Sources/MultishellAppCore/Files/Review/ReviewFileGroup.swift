import MultishellCore

/// A file's comments under its name, in Review.
public struct ReviewFileGroup: Identifiable, Equatable, Sendable {
  /// Relative to the worktree.
  public let path: String
  public let fileName: String
  /// "1 to send", or "2 comments" with none pending.
  public let countText: String
  public let rows: [ReviewRow]

  public var id: String { path }
}
