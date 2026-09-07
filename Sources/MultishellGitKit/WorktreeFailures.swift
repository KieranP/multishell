import Foundation

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
