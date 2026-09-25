import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// What the sidebar draws for one worktree.
  public func mergeState(of worktree: Worktree) -> WorktreeMergeState {
    mergeStates[worktree.id] ?? .unknown
  }

  /// The branch this project's merges are measured against, `nil` while
  /// none has been resolved. What the settings panel shows as detected.
  public func defaultBranch(of project: Project) -> DefaultBranch? {
    defaultBranches[project.id]
  }

  /// What the default-branch field shows while not overridden, and seeds an
  /// override with: the detected branch without its remote, else the usual.
  public func defaultBranchName(of project: Project) -> String {
    defaultBranch(of: project)?.branchName ?? Self.usualDefaultBranchName
  }

  public static var usualDefaultBranchName: String { "main" }

  /// Whether each worktree's branch has landed. On the status poll, not the
  /// watcher: a commit moves a ref no watched file mentions.
  func refreshMergeStates() async {
    let projects = workspace.projects.filter { !missingProjects.contains($0.id) }
    mergeReads.beginRound()
    // A few at once: one git per project per tick, serially, was the tick's
    // longest wait at ten projects. Each writes only its own worktrees' ids.
    await projects.mapConcurrentlyUnordered(width: Self.concurrentMergeRefreshes) { project in
      await self.refreshMergeStates(of: project, inRound: true)
    }
  }

  private static var concurrentMergeRefreshes: Int { 4 }

  /// `inRound` inside the poll's round, whose projects share one budget.
  func refreshMergeStates(of project: Project, inRound: Bool = false) async {
    guard let coordinator else { return }
    // Resolved here, not taken from the caller: `fetch` holds its project
    // across a network call, so its copy can predate a read of the file.
    let project = workspace.project(project.id) ?? project
    let override = effectiveSettings(for: project).defaultBranch
    let branches = await coordinator.scanBranches(of: project, defaultBranchOverride: override)
    // Gone, or renamed, while git ran.
    guard workspace.project(project.id) != nil else { return }
    // A ref read that failed is not a repository with no branches: the
    // badges and the commit dates stand until one answers.
    guard let branches else { return }
    // Before the base is resolved, and whether or not it can be: a
    // repository with no trunk still has branches to order.
    recordLastCommits(branches.lastCommits, of: project.id)
    guard let inputs = branches.mergeInputs else {
      // No branch to measure against: drop the badges rather than leave
      // them about a base that no longer applies.
      forgetMergeStates(ofProject: project.id)
      recordDefaultBranch(nil, of: project.id)
      return
    }
    recordDefaultBranch(inputs.base, of: project.id)

    let plan = planMergeChecks(of: project.id, against: inputs)
    forgetMergeStates(ofWorktrees: plan.unbadgeable)
    // The rest keep their stale check, so the next round asks them. A branch
    // checked out in two worktrees is asked about once.
    let admitted = mergeReads.admit(plan.waiting.map(\.id), sharingRound: inRound)
    let asking = Set(plan.waiting.filter { admitted.contains($0.id) }.map(\.branch))
    let fresh = await coordinator.readMerges(of: asking.sorted(), in: project, inputs: inputs)
    recordMergeReadings(fresh, checks: plan.checks, of: project.id)
  }

  /// What each of the project's worktrees would be checked against, which of
  /// those have moved since their answer, and which can carry no badge.
  private func planMergeChecks(of id: Project.ID, against inputs: MergeInputs) -> MergeCheckPlan {
    var plan = MergeCheckPlan()
    for worktree in workspace.worktrees(of: id) {
      // A stage keeps what it earned and is asked nothing; a claimed path
      // forgets, the last checkout there being gone. See worktrees.md.
      if worktreeOperations.isUnderWay(worktree.id) { continue }
      guard !pathClaims.isClaimed(worktree.id), !worktree.isInitializing,
        WorktreeMergeState.applies(to: worktree, base: inputs.base.branchName),
        let branch = worktree.branch, let tip = inputs.tip(of: branch)
      else {
        plan.unbadgeable.append(worktree.id)
        continue
      }
      let check = MergeCheck(
        base: inputs.base.shortName, baseTip: inputs.base.tip, branch: branch, tip: tip,
        upstreamIsGone: inputs.upstreamIsGone(branch))
      plan.checks[worktree.id] = check
      // Nothing has moved since the answer we have, so nothing to ask.
      guard mergeChecks[worktree.id] != check || mergeStates[worktree.id] == nil else { continue }
      plan.waiting.append((worktree.id, branch))
    }
    return plan
  }

  /// The worktrees may have changed under the git calls; only what is still
  /// there and still on the branch it was checked on is kept.
  private func recordMergeReadings(
    _ fresh: [String: MergeReading], checks: [Worktree.ID: MergeCheck], of id: Project.ID
  ) {
    for worktree in workspace.worktrees(of: id) {
      guard let check = checks[worktree.id], check.branch == worktree.branch,
        let reading = fresh[check.branch], !isUnderConstruction(worktree)
      else { continue }
      // A failed read is logged too, or it sorts first every round at the guess.
      mergeReads.remember([worktree.id: reading.took])
      // Only an answer settles it: stamping the check for a failed read
      // pins the old verdict to the new tip for good.
      guard let state = reading.state else { continue }
      setIfChanged(\.mergeStates[worktree.id], state)
      mergeChecks[worktree.id] = check
    }
  }

  private func recordDefaultBranch(_ base: DefaultBranch?, of id: Project.ID) {
    setIfChanged(\.defaultBranches[id], base)
  }

  /// The scan answers by branch, the sidebar asks by worktree.
  private func recordLastCommits(_ dates: [String: Date], of id: Project.ID) {
    var fresh = lastCommits
    for worktree in workspace.worktrees(of: id) {
      fresh[worktree.id] = worktree.branch.flatMap { dates[$0] }
    }
    setIfChanged(\.lastCommits, fresh)
  }

  private func forgetMergeStates(ofWorktrees ids: [Worktree.ID]) {
    for id in ids {
      setIfChanged(\.mergeStates[id], nil)
      mergeChecks[id] = nil
    }
    mergeReads.forget(ids)
  }

  /// Where a project's default branch has gone: its badges are about a base
  /// that no longer applies. A removed project goes through `forgetWorktrees`.
  func forgetMergeStates(ofProject project: Project.ID) {
    forgetMergeStates(ofWorktrees: workspace.worktrees(of: project).map(\.id))
  }
}

private struct MergeCheckPlan {
  var checks: [Worktree.ID: MergeCheck] = [:]
  var waiting: [(id: Worktree.ID, branch: String)] = []
  var unbadgeable: [Worktree.ID] = []
}
