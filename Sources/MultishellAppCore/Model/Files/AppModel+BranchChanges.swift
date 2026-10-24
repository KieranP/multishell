import MultishellCore
import MultishellGitKit

/// The Files panel's Branch list: what its worktree changed since the branch
/// left its project's base branch; see Docs/design/files.md.
extension AppModel {
  private var listsBranchChanges: Bool {
    workspace.filesPanelMode == .git && workspace.changeScope == .branch
  }

  /// What the panel counts the worktree's changes against, as its footer says.
  func changeComparison(of id: Worktree.ID) -> ChangeComparison {
    guard listsBranchChanges, let worktree = workspace.worktree(id) else { return .head }
    guard let scanned = defaultBranchScans[worktree.projectID] else { return .unread }
    guard let base = scanned.branch else { return .noBase }
    // An override changing the base leaves the last read describing the old one.
    guard let changes = branchChanges[id], changes.baseName == base.shortName else {
      let hasFailed = failedBranchReads[id] == base.shortName
      return hasFailed ? .unreadable(baseName: base.shortName) : .unread
    }
    return .branch(changes)
  }

  /// Leaving Branch lets go of what it read, so coming back draws none as current.
  func forgetBranchChangesUnlessListed() {
    guard !listsBranchChanges else { return }
    branchChangesReads.cancel { _ in true }
    setIfChanged(\.branchChanges, [:])
    setIfChanged(\.failedBranchReads, [:])
  }

  /// The panel's worktree's, where it lists Branch.
  func schedulePanelBranchChangesRead() {
    if let worktree = filesPanelWorktree { scheduleBranchChangesRead(of: worktree.id) }
  }

  /// Paced, as every status landing asks for one.
  func scheduleBranchChangesRead(of id: Worktree.ID) {
    guard showsFilesPanel, filesPanelWorktree?.id == id, listsBranchChanges, let coordinator,
      let worktree = workspace.worktree(id), mayReadStatus(of: worktree),
      let base = defaultBranch(ofWorktree: id),
      // Its new files come from the status read, whose landing asks again.
      let status = statuses[id]
    else { return }
    let algorithm = workspace.diffAlgorithm
    let git = coordinator.git
    schedulePacedRead(
      id,
      in: id,
      on: \.branchChangesReads,
      reading: {
        await git.branchChanges(
          inRepositoryAt: worktree.path,
          since: base,
          status: status,
          diffAlgorithm: algorithm,
        )
      },
      landing: { model, changes in
        // A failed read keeps the last one rather than reading as no changes, and one
        // a new algorithm or base overtook leaves it to the read asked for since.
        guard model.workspace.diffAlgorithm == algorithm,
          model.defaultBranch(ofWorktree: id) == base
        else { return }
        if let changes { model.setIfChanged(\.branchChanges[id], changes) }
        model.setIfChanged(\.failedBranchReads[id], changes == nil ? base.shortName : nil)
      },
      rerun: { $0.scheduleBranchChangesRead(of: id) },
    )
  }
}
