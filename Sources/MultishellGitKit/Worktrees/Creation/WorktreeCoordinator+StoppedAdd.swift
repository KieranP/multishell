import Foundation
import MultishellCore

extension WorktreeCoordinator {
  /// What a stopped add would leave behind, read before the add starts.
  func stoppedAddUndo(
    at path: URL,
    branch: String,
    createsBranch: Bool,
    in project: Project,
  ) async -> StoppedAddUndo {
    // No container directory made here: `git worktree add` makes the leading
    // directories itself, and a refused add then leaves none behind.
    let highestMissingAncestor = await runOnDispatch { path.highestMissingAncestor }
    // Asked first: a stop can land before git has made anything, and the
    // name may be a branch of the user's that the add was refusing.
    let branchIsNew = createsBranch ? await git.lacksBranch(branch, in: project) : false
    // An unforced remove still forgets a registered worktree whose directory is
    // away. Asked even where the path exists: git fills an empty directory.
    let worktreeIsNew = await !git.isListed(path, in: project)
    return StoppedAddUndo(
      path: path,
      worktreeIsNew: worktreeIsNew,
      newBranch: branchIsNew ? branch : nil,
      highestMissingAncestor: highestMissingAncestor,
    )
  }

  /// A stopped add leaves its new branch and its directories, and the worktree
  /// where git had finished, so the same name could not be tried again.
  func undoStoppedAdd(_ undo: StoppedAddUndo, in project: Project) async {
    if undo.worktreeIsNew { await git.removeUnchanged(undo.path, in: project) }
    if let newBranch = undo.newBranch { await git.deleteBranchIfUnlisted(newBranch, in: project) }
    if let highestMissingAncestor = undo.highestMissingAncestor {
      await runOnDispatch { undo.path.removeEmptyDirectories(through: highestMissingAncestor) }
    }
  }
}
