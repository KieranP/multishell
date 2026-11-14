import MultishellGitKit

/// One file as the Changes list counts it: what the header's letter and, for a
/// file with no rows to count, its `+n −n` come from.
public struct AllChangesFileChange: Hashable, Sendable {
  /// Relative to the worktree.
  public let path: String
  public let kind: StatusChange.Kind
  /// `nil` for a change git scores no lines for, a binary file's.
  public let lineCounts: FileLineCounts?
}
