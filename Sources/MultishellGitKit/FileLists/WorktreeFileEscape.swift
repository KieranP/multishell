/// A listed path leading out of the repository or worktree, by `..` or a
/// symlinked folder.
public struct WorktreeFileEscape: Error, CustomStringConvertible {
  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "leads outside the repository or the worktree" }
}
