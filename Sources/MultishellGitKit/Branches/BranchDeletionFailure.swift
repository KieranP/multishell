/// The worktree is gone but its branch is not: git refused to delete it,
/// usually because it has commits no other branch has.
public struct BranchDeletionFailure: Error, CustomStringConvertible {
  public let branch: String
  /// Where the branch pointed when git refused, which a forced retry holds it to.
  public let tip: String?
  public let underlying: any Error

  public var description: String {
    "branch \(branch) was not deleted: \(underlying)"
  }
}
