import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  private static var concurrentBranchScans: Int { 4 }

  /// What the sidebar draws for one worktree.
  public func mergeState(of worktree: Worktree) -> WorktreeMergeState {
    mergeStates[worktree.id] ?? .unknown
  }

  /// Each branch's last commit, the default branch and whether each worktree's
  /// branch has landed. On the poll: a commit moves a ref nothing watched names.
  func refreshBranchScans() async {
    let projects = workspace.projects.filter { !missingProjects.contains($0.id) }
    mergeReadLog.beginRound()
    // A few at once: one git per project per tick, serially, was the tick's
    // longest wait at ten projects. Each writes only its own worktrees' ids.
    await projects.mapConcurrentlyUnordered(width: Self.concurrentBranchScans) { project in
      await self.refreshBranchScan(of: project, sharingRound: true)
    }
  }

  /// `sharingRound` inside the poll's round, whose projects share one budget.
  func refreshBranchScan(of project: Project, sharingRound: Bool = false) async {
    guard let coordinator else { return }
    // Resolved here, not taken from the caller: `fetch` holds its project
    // across a network call, so its copy can predate a read of the file.
    let project = currentCopy(of: project)
    let override = effectiveSettings(for: project).defaultBranch
    let scan = await coordinator.scanBranches(of: project, defaultBranchOverride: override)
    // Gone, or renamed, while git ran.
    guard workspace.project(project.id) != nil else { return }
    // A ref read that failed is not a repository with no branches: the
    // badges and the commit dates stand until one answers.
    guard let scan else { return }
    // Before the base is resolved, and whether or not it can be: a
    // repository with no trunk still has branches to order.
    recordLastCommitDates(scan.lastCommitDates, of: project.id)
    guard let inputs = scan.mergeInputs else {
      // No branch to measure against: drop the badges rather than leave
      // them about a base that no longer applies.
      forgetMergeStates(ofProject: project.id)
      recordDefaultBranch(nil, of: project.id)
      return
    }
    recordDefaultBranch(inputs.defaultBranch, of: project.id)

    let plan = planMergeReads(of: project.id, against: inputs)
    forgetMergeStates(ofWorktrees: plan.unbadgeable)
    // The rest keep their stale basis, so the next round asks them. A branch
    // checked out in two worktrees is asked about once.
    let admitted = mergeReadLog.admit(plan.toAsk.map(\.id), sharingRound: sharingRound)
    let asking = Set(plan.toAsk.filter { admitted.contains($0.id) }.map(\.branch))
    let fresh = await coordinator.readMerges(of: asking.sorted(), in: project, inputs: inputs)
    recordMergeReadings(fresh, verdictBases: plan.verdictBases, of: project.id)
  }

  /// What each of the project's worktrees would be checked against, which of
  /// those have moved since their answer, and which can carry no badge.
  private func planMergeReads(of id: Project.ID, against inputs: MergeInputs) -> MergeReadPlan {
    var plan = MergeReadPlan()
    for worktree in workspace.worktrees(of: id) {
      // A stage keeps what it earned and is asked nothing; a claimed path
      // forgets, the last checkout there being gone. See worktrees.md.
      if worktreeOperations.isRunning(worktree.id) { continue }
      guard !pathClaims.isClaimed(worktree.id), !worktree.isInitializing,
        WorktreeMergeState.applies(
          to: worktree,
          defaultBranchName: inputs.defaultBranch.nameWithoutRemote,
        ),
        let branch = worktree.branch, let tip = inputs.tip(of: branch)
      else {
        plan.unbadgeable.append(worktree.id)
        continue
      }
      let basis = MergeVerdictBasis(
        defaultBranchName: inputs.defaultBranch.shortName,
        defaultBranchTip: inputs.defaultBranch.tip,
        branch: branch,
        branchTip: tip,
        upstreamIsGone: inputs.upstreamIsGone(branch),
      )
      plan.verdictBases[worktree.id] = basis
      // Nothing has moved since the answer we have, so nothing to ask.
      guard mergeVerdictBases[worktree.id] != basis || mergeStates[worktree.id] == nil else {
        continue
      }
      plan.toAsk.append((worktree.id, branch))
    }
    return plan
  }

  /// The worktrees may have changed under the git calls; only what is still
  /// there and still on the branch it was checked on is kept.
  private func recordMergeReadings(
    _ fresh: [String: MergeReading],
    verdictBases: [Worktree.ID: MergeVerdictBasis],
    of id: Project.ID,
  ) {
    for worktree in workspace.worktrees(of: id) {
      guard let basis = verdictBases[worktree.id], basis.branch == worktree.branch,
        let reading = fresh[basis.branch], !isBeingWritten(worktree)
      else { continue }
      // A failed read is logged too, or it stays unread and is let in every round.
      mergeReadLog.remember([worktree.id: reading.duration])
      // Only an answer settles it: stamping the basis for a failed read
      // pins the old verdict to the new tip for good.
      guard let state = reading.state else { continue }
      setIfChanged(\.mergeStates[worktree.id], state)
      mergeVerdictBases[worktree.id] = basis
    }
  }

  private func recordDefaultBranch(_ defaultBranch: DefaultBranch?, of id: Project.ID) {
    setIfChanged(\.defaultBranches[id], defaultBranch)
  }

  /// The scan answers by branch, the sidebar asks by worktree.
  private func recordLastCommitDates(_ dates: [String: Date], of id: Project.ID) {
    var fresh = lastCommitDates
    for worktree in workspace.worktrees(of: id) {
      fresh[worktree.id] = worktree.branch.flatMap { dates[$0] }
    }
    setIfChanged(\.lastCommitDates, fresh)
  }

  func forgetMergeStates(ofWorktrees ids: some Sequence<Worktree.ID>) {
    let gone = Set(ids)
    setIfChanged(\.mergeStates, mergeStates.filter { !gone.contains($0.key) })
    mergeVerdictBases = mergeVerdictBases.filter { !gone.contains($0.key) }
    mergeReadLog.forget(gone)
  }

  /// Where a project's default branch has gone: its badges are about a base
  /// that no longer applies. A removed project goes through `forgetWorktrees`.
  func forgetMergeStates(ofProject id: Project.ID) {
    forgetMergeStates(ofWorktrees: workspace.worktrees(of: id).map(\.id))
  }
}
