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
  public func mergeBase(of project: Project) -> DefaultBranch? {
    mergeBases[project.id]
  }

  /// Whether each worktree's branch has landed. On the status poll, not the
  /// watcher: a commit moves a ref no watched file mentions.
  func refreshMergeStates() async {
    let projects = workspace.projects.filter { !missingProjects.contains($0.id) }
    mergeReads.beginRound()
    // A few at once: one git per project per tick, serially, was the tick's
    // longest wait at ten projects. Each writes only its own worktrees' ids.
    await withTaskGroup(of: Void.self) { group in
      var pending = projects.makeIterator()
      func startNext() {
        guard let project = pending.next() else { return }
        group.addTask { await self.refreshMergeStates(of: project, inRound: true) }
      }
      for _ in 0..<Self.concurrentBranchScans { startNext() }
      for await _ in group { startNext() }
    }
  }

  static var concurrentBranchScans: Int { 4 }

  /// `inRound` inside the poll's round, whose projects share one budget.
  func refreshMergeStates(of project: Project, inRound: Bool = false) async {
    guard let worktrees else { return }
    // Resolved here, not taken from the caller: `fetch` holds its project
    // across a network call, so its copy can predate a read of the file.
    let project = workspace.project(project.id) ?? project
    let override = effectiveSettings(for: project).defaultBranch
    let branches = await worktrees.scanBranches(of: project, defaultBranch: override)
    // Gone, or renamed, while git ran.
    guard workspace.project(project.id) != nil else { return }
    // A ref read that failed is not a repository with no branches: the
    // badges and the commit dates stand until one answers.
    guard let branches else { return }
    // Before the base is resolved, and whether or not it can be: a
    // repository with no trunk still has branches to order.
    note(branches.lastCommits, asLastCommitsOf: project.id)
    guard let scan = branches.merges else {
      // No branch to measure against: drop the badges rather than leave
      // them about a base that no longer applies.
      forgetMergeStates(of: project.id)
      note(nil, asMergeBaseOf: project.id)
      return
    }
    note(scan.base, asMergeBaseOf: project.id)

    var checks: [Worktree.ID: MergeCheck] = [:]
    var waiting: [(id: Worktree.ID, branch: String)] = []
    var unbadgeable: [Worktree.ID] = []
    for worktree in workspace.worktrees(of: project.id) {
      // A stage keeps what it earned and is asked nothing; a claimed path
      // forgets, the last checkout there being gone. See worktrees.md.
      if worktreeOperations.isUnderWay(worktree.id) { continue }
      guard !workInFlight.isClaimed(worktree.id), !worktree.isInitializing,
        WorktreeMergeState.applies(to: worktree, base: scan.base.branch),
        let branch = worktree.branch, let tip = scan.tip(of: branch)
      else {
        unbadgeable.append(worktree.id)
        continue
      }
      let check = MergeCheck(
        base: scan.base.ref, baseTip: scan.base.tip, branch: branch, tip: tip,
        upstreamIsGone: scan.upstreamIsGone(branch))
      checks[worktree.id] = check
      // Nothing has moved since the answer we have, so nothing to ask.
      guard mergeChecks[worktree.id] != check || mergeStates[worktree.id] == nil else { continue }
      waiting.append((worktree.id, branch))
    }
    forget(unbadgeable)

    // The rest keep their stale check, so the next round asks them. A branch
    // checked out in two worktrees is asked about once.
    let admitted = mergeReads.admit(waiting.map(\.id), sharingRound: inRound)
    let asking = Set(waiting.filter { admitted.contains($0.id) }.map(\.branch))
    let fresh = await worktrees.mergeReadings(of: asking.sorted(), in: project, scan: scan)
    // The worktrees may have changed under the git calls above; only what
    // is still there and still on that branch is kept.
    for worktree in workspace.worktrees(of: project.id) {
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

  private func note(_ base: DefaultBranch?, asMergeBaseOf id: Project.ID) {
    setIfChanged(\.mergeBases[id], base)
  }

  /// The scan answers by branch, the sidebar asks by worktree.
  private func note(_ dates: [String: Date], asLastCommitsOf id: Project.ID) {
    var fresh = lastCommits
    for worktree in workspace.worktrees(of: id) {
      fresh[worktree.id] = worktree.branch.flatMap { dates[$0] }
    }
    setIfChanged(\.lastCommits, fresh)
  }

  private func forget(_ ids: [Worktree.ID]) {
    for id in ids {
      setIfChanged(\.mergeStates[id], nil)
      mergeChecks[id] = nil
    }
    mergeReads.forget(ids)
  }

  /// Where a project's default branch has gone: its badges are about a base
  /// that no longer applies. A removed project goes through `forgetWorktrees`.
  func forgetMergeStates(of project: Project.ID) {
    forget(workspace.worktrees(of: project).map(\.id))
  }

  /// Whether a fetch is running on this project: its row spins, and the
  /// menu item that started it is disabled until it ends.
  public func isFetching(_ project: Project) -> Bool {
    fetchingProjects.contains(project.id)
  }

  /// The menus' Fetch, the one git call that talks to a network and only on
  /// a click. Marked for the whole of it, re-reads included.
  public func fetch(_ project: Project) async {
    guard let worktrees, fetchingProjects.insert(project.id).inserted else { return }
    defer { fetchingProjects.remove(project.id) }
    do {
      try await worktrees.fetch(project)
    } catch {
      report(error)
      return
    }
    await refresh(project)
    await refreshStatuses()
    await refreshMergeStates(of: project)
  }
}
