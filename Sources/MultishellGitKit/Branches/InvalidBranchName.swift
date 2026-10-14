/// A branch name git would refuse. Raised before the pre-create hook runs,
/// so a name that could never become a worktree runs nothing.
public struct InvalidBranchName: Error, CustomStringConvertible {
  public let branch: String

  /// The log's form. What the user is shown is `PresentedError`'s.
  public var description: String { "git would refuse the branch name \(branch)" }

  init(_ branch: String) {
    self.branch = branch
  }
}
