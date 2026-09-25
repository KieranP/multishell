import Foundation
import MultishellCore

/// The repository itself, handed to a call that removes a worktree. The
/// only guard was a view three modules away; see Docs/design/worktrees.md.
public struct NotAWorktree: LocalizedError {
  public let path: URL

  init(path: URL) {
    self.path = path
  }

  public var errorDescription: String? {
    t("worktree.not-removable", path.path)
  }
}
