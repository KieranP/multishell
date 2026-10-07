import Foundation
import MultishellCore

/// The repository itself, handed to a call that removes a worktree. The
/// only guard was a view three modules away; see Docs/design/worktrees.md.
public struct WorktreeNotRemovable: LocalizedError {
  let path: URL

  public var errorDescription: String? {
    t("worktree.not-removable", path.path)
  }
}
