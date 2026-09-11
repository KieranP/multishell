import Foundation
import MultishellCore
import MultishellGitKit

// MARK: - Merged branches

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
  public func refreshMergeStates() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshMergeStates(of: project)
    }
    forgetVanishedWorktrees()
  }

  func refreshMergeStates(of project: Project) async {
    guard let worktrees else { return }
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
    var asking: Set<String> = []
    var unbadgeable: [Worktree.ID] = []
    for worktree in workspace.worktrees(of: project.id) {
      guard WorktreeMergeState.applies(to: worktree, base: scan.base.branch),
        let branch = worktree.branch, let tip = scan.tip(of: branch)
      else {
        unbadgeable.append(worktree.id)
        continue
      }
      let check = MergeCheck(
        base: scan.base.ref, baseTip: scan.base.tip, branch: branch, tip: tip,
        upstreamIsGone: scan.upstreamIsGone(branch))
      checks[worktree.id] = check
      // Nothing has moved since the answer we have, so nothing to ask. A
      // branch checked out in two worktrees is asked about once.
      guard mergeChecks[worktree.id] != check || mergeStates[worktree.id] == nil else { continue }
      asking.insert(branch)
    }
    forget(unbadgeable)

    let fresh = await worktrees.mergeStates(of: asking.sorted(), in: project, scan: scan)
    // The worktrees may have changed under the git calls above; only what
    // is still there and still on that branch is kept.
    for worktree in workspace.worktrees(of: project.id) {
      guard let check = checks[worktree.id], check.branch == worktree.branch,
        let state = fresh[check.branch]
      else { continue }
      // Only an answer settles it: stamping the check for a failed read
      // pins the old verdict to the new tip for good.
      if mergeStates[worktree.id] != state { mergeStates[worktree.id] = state }
      mergeChecks[worktree.id] = check
    }
  }

  /// Written only where something changed: these land on the status poll,
  /// and an unchanged entry still redraws every view watching it.
  private func note(_ base: DefaultBranch?, asMergeBaseOf id: Project.ID) {
    if mergeBases[id] != base { mergeBases[id] = base }
  }

  /// The scan answers by branch, the sidebar asks by worktree. Written back
  /// only when something moved.
  private func note(_ dates: [String: Date], asLastCommitsOf id: Project.ID) {
    var fresh = lastCommits
    for worktree in workspace.worktrees(of: id) {
      fresh[worktree.id] = worktree.branch.flatMap { dates[$0] }
    }
    if fresh != lastCommits { lastCommits = fresh }
  }

  private func forget(_ ids: [Worktree.ID]) {
    for id in ids where mergeStates[id] != nil { mergeStates[id] = nil }
    for id in ids where mergeChecks[id] != nil { mergeChecks[id] = nil }
  }

  /// What a refresh found gone. Paths are ids, so a worktree made where one
  /// was removed would otherwise inherit its badge and its date.
  func forgetVanishedWorktrees() {
    let known = Set(workspace.worktrees.map(\.id))
    let states = mergeStates.filter { known.contains($0.key) }
    if states.count != mergeStates.count { mergeStates = states }
    let dates = lastCommits.filter { known.contains($0.key) }
    if dates.count != lastCommits.count { lastCommits = dates }
    mergeChecks = mergeChecks.filter { known.contains($0.key) }
  }

  /// After a project is removed, and where its default branch has gone.
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

/// What a worktree's merge verdict was computed from, so a refresh finding
/// it unmoved asks git nothing. The branch and its gone upstream are in it.
struct MergeCheck: Equatable, Sendable {
  let base: String
  let baseTip: String
  let branch: String
  let tip: String
  let upstreamIsGone: Bool
}
