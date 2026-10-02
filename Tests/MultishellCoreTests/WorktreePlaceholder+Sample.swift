import Foundation

@testable import MultishellCore

extension WorktreePlaceholder {
  static let sampleProject = Project(path: URL(fileURLWithPath: "/Users/dev/Work/multishell"))

  /// A worktree of `sampleProject` on `kieran/fix`, which the sidebar calls "The fix".
  static var sampleValues: [WorktreePlaceholder: String] {
    values(
      project: sampleProject,
      worktree: Worktree(
        path: URL(fileURLWithPath: "/Users/dev/Work/multishell-worktrees/fix"),
        projectID: sampleProject.id, head: "abc1234", branch: "kieran/fix"),
      worktreeName: "The fix")
  }
}
