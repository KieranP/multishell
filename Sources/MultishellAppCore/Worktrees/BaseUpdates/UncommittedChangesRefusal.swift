import MultishellCore
import MultishellGitKit

/// A merge or rebase from the base refused over uncommitted changes, which are
/// never stashed: an agent may be mid-edit, and the stash is every worktree's.
struct UncommittedChangesRefusal: Error, CustomStringConvertible {
  let branch: String
  let method: UpdateMethod
  let base: DefaultBranch
  /// As status prints each, `M src/a.js`.
  let changes: [String]

  /// The log's form. What the user is shown is `PresentedError`'s.
  var description: String { "\(branch) has \(changes.count) uncommitted change(s)" }
}
