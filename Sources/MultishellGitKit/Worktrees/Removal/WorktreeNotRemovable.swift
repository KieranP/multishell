import Foundation

/// The repository itself, handed to a call that removes a worktree. The
/// only guard was a view three modules away; see Docs/design/worktrees.md.
public struct WorktreeNotRemovable: Error, CustomStringConvertible {
  public let path: URL

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "\(path.path) is the repository, not a worktree" }
}
