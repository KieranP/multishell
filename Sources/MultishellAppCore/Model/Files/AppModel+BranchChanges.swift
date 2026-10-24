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

  /// One read per worktree at a time, paced by its cost; one asked for meanwhile
  /// runs once it is due.
  func scheduleBranchChangesRead(of id: Worktree.ID) {
    guard showsFilesPanel, filesPanelWorktree?.id == id, listsBranchChanges, let coordinator,
      let worktree = workspace.worktree(id), mayReadStatus(of: worktree),
      let base = defaultBranch(ofWorktree: id),
      // Its new files come from the status read, whose landing asks again.
      let status = statuses[id]
    else { return }
    let algorithm = workspace.diffAlgorithm
    branchChangesReads.start(id) {
      Task { @MainActor [weak self] in
        let started = ContinuousClock.now
        let changes = await coordinator.git.branchChanges(
          inRepositoryAt: worktree.path,
          since: base,
          status: status,
          diffAlgorithm: algorithm,
        )
        let cost = started.duration(to: .now)
        // A failed read keeps the last one rather than reading as no changes, and one
        // a new algorithm or base overtook leaves it to the read asked for since.
        if let self, !Task.isCancelled, workspace.worktree(id) != nil,
          workspace.diffAlgorithm == algorithm, defaultBranch(ofWorktree: id) == base
        {
          if let changes { setIfChanged(\.branchChanges[id], changes) }
          setIfChanged(\.failedBranchReads[id], changes == nil ? base.shortName : nil)
        }
        guard let pause = self?.pause(afterReadCosting: cost, in: id) else { return }
        try? await Task.sleep(for: pause)
        guard let self, !Task.isCancelled else { return }
        if branchChangesReads.finish(id) { scheduleBranchChangesRead(of: id) }
      }
    }
  }
}
