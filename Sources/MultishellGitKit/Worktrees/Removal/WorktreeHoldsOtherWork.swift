import Foundation

/// A worktree whose removal would take work kept nowhere else: another
/// worktree checked out inside it, or work in a submodule's repository, which
/// git keeps under the worktree's record; see worktrees/creating-and-removing.md.
public struct WorktreeHoldsOtherWork: Error, CustomStringConvertible {
  public enum Work: Sendable, Equatable {
    case worktree(URL)
    case submodules
  }

  public let path: URL
  public let work: Work

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String {
    switch work {
    case .worktree(let inner): "\(path.path) holds the worktree \(inner.path)"
    case .submodules: "\(path.path) holds submodule work no remote has"
    }
  }
}
