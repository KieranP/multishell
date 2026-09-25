import Foundation
import MultishellCore

/// A branch name git would refuse. Raised before the pre-create hook runs,
/// so a name that could never become a worktree runs nothing.
public struct InvalidBranchName: LocalizedError {
  public let branch: String

  init(_ branch: String) {
    self.branch = branch
  }

  public var errorDescription: String? {
    t("branch-name.invalid", branch)
  }
}
