/// Uncommitted changes cut for reading, as the alert and `worktrees update`'s refusal
/// both list them: a build folder's thousands would fill either.
public struct UncommittedChangeList: Equatable, Sendable {
  private static let limit = 12

  public let shown: [String]
  /// Those past the limit, said as a count.
  public let unlisted: Int

  public init(_ changes: [String]) {
    shown = Array(changes.prefix(Self.limit))
    unlisted = changes.count - shown.count
  }
}
