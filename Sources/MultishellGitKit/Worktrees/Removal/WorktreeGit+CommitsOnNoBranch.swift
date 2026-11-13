import Foundation
import MultishellCore

extension WorktreeGit {
  /// Commits HEAD holds that no branch, remote or tag does: a detached worktree's
  /// own work, which its removal takes with the record's reflog. `nil` where git cannot say.
  public func commitsOnNoBranch(in worktree: Worktree) async -> Int? {
    let arguments = [
      "rev-list", "--count", "HEAD", "--not", "--branches", "--remotes", "--tags", "--",
    ]
    return await runner.output(arguments, in: worktree.path).flatMap(RevListCountParser.parse)
  }
}
