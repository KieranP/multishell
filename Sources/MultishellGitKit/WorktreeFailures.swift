import Foundation
import MultishellCore

/// The repository itself, handed to a call that removes a worktree. The
/// only guard was a view three modules away; see docs/design/worktrees.md.
public struct NotAWorktree: LocalizedError {
  public let path: URL

  public init(path: URL) {
    self.path = path
  }

  public var errorDescription: String? {
    t("worktree.not-removable", path.path)
  }
}

/// A branch name git would refuse. Raised before the pre-create hook runs,
/// so a name that could never become a worktree runs nothing.
public struct InvalidBranchName: LocalizedError {
  public let branch: String

  public init(_ branch: String) {
    self.branch = branch
  }

  public var errorDescription: String? {
    t("branch-name.invalid", branch)
  }
}

/// The platform could not move the worktree directory to the Trash. The
/// worktree is still there and still registered.
public struct TrashFailure: Error, CustomStringConvertible {
  public let path: URL
  public let underlying: any Error

  public init(path: URL, underlying: any Error) {
    self.path = path
    self.underlying = underlying
  }

  public var description: String {
    "\(path.path) could not be moved to the Trash: \(underlying)"
  }
}

/// The Trash reported success with the directory still in place, so the
/// removal stopped rather than let git unlink it.
public struct TrashTookNothing: Error, CustomStringConvertible {
  public init() {}
  public var description: String { "the directory is still there" }
}

/// The directory is in the Trash and git still lists the worktree: neither
/// `worktree remove` nor `prune` would let go of the record.
public struct WorktreeForgetFailure: Error, CustomStringConvertible {
  public let path: URL
  public let underlying: any Error

  public init(path: URL, underlying: any Error) {
    self.path = path
    self.underlying = underlying
  }

  public var description: String {
    "\(path.path) is in the Trash but git still lists it: \(underlying)"
  }
}

/// The worktree is gone but its branch is not: git refused to delete it,
/// usually because it has commits no other branch has.
public struct BranchDeletionFailure: Error, CustomStringConvertible {
  public let branch: String
  public let underlying: any Error

  public init(branch: String, underlying: any Error) {
    self.branch = branch
    self.underlying = underlying
  }

  public var description: String {
    "branch \(branch) was not deleted: \(underlying)"
  }
}
