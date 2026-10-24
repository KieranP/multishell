/// One path's change as a status read counted it. Every count a worktree shows
/// is a sum over these; see Docs/design/files.md.
public struct StatusChange: Hashable, Sendable {
  /// What the change does to the path, which colours its dot.
  public enum Kind: Hashable, Sendable {
    case added
    case deleted
    case modified

    /// One path listed twice, removed from the index and left on disk, is the
    /// new file it is.
    public func combined(with other: Self) -> Self {
      self == .added || other == .added ? .added : other
    }
  }

  public enum Lines: Hashable, Sendable {
    case counted(insertions: Int, deletions: Int)
    /// In neither the lines nor `~N`: unmerged, or past the untracked caps.
    case notCounted
    /// No line to show, counted in `~N`: binary, mode-only, too big to read.
    case unscored
  }

  /// Relative to the worktree, as git prints it with `-z`.
  public let path: String
  public let kind: Kind
  public let lines: Lines

  /// The same change as the repository around this one lists it, this one
  /// sitting at `folder`: a submodule's file in the worktree's tree.
  public func prefixed(byFolder folder: String) -> Self {
    Self(path: folder + "/" + path, kind: kind, lines: lines)
  }
}
