/// The worktree is gone but its branch is not: git refused to delete it,
/// usually because it has commits no other branch has.
public struct BranchDeletionFailure: Error, CustomStringConvertible {
  public let branch: String
  public let underlying: any Error

  public var description: String {
    "branch \(branch) was not deleted: \(underlying)"
  }
}
