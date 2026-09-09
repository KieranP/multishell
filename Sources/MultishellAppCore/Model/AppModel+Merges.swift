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

  /// Whether each worktree's branch has already landed, for every project.
  ///
  /// On the status poll rather than the watcher: a commit moves
  /// `refs/heads/<branch>`, which no file the watcher compares mentions, so
  /// nothing else would see the last change of a branch land. What it costs
  /// on a tick where nothing moved is two `for-each-ref`-shaped reads per
  /// project, next to the `git status` the same tick already runs per
  /// worktree.
  public func refreshMergeStates() async {
    for project in workspace.projects where !missingProjects.contains(project.id) {
      await refreshMergeStates(of: project)
    }
    let known = Set(workspace.worktrees.map(\.id))
    let kept = mergeStates.filter { known.contains($0.key) }
    if kept.count != mergeStates.count { mergeStates = kept }
    mergeChecks = mergeChecks.filter { known.contains($0.key) }
    let dates = lastCommits.filter { known.contains($0.key) }
    if dates.count != lastCommits.count { lastCommits = dates }
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
    // Before the base is resolved, and whether or not it can be: the
    // sidebar orders by these, and a repository with no trunk still has
    // branches that were committed to.
    note(branches.lastCommits, asLastCommitsOf: project.id)
    guard let scan = branches.merges else {
      // No branch to measure against, or one the user named that is not
      // there: drop the badges rather than leave them saying something
      // about a base that no longer applies.
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
      // Only an answer settles the question. A read that failed brings
      // none, and stamping the check for it would pin the verdict it could
      // not replace to the new tip, never to be asked about again.
      if mergeStates[worktree.id] != state { mergeStates[worktree.id] = state }
      mergeChecks[worktree.id] = check
    }
  }

  /// Every write here lands on the status poll, so each one is made only
  /// where it changes something: putting a dictionary entry back unchanged
  /// still tells every view watching it to draw again, and the sidebar
  /// would redraw every five seconds for nothing.
  private func note(_ base: DefaultBranch?, asMergeBaseOf id: Project.ID) {
    if mergeBases[id] != base { mergeBases[id] = base }
  }

  /// The scan answers by branch; the sidebar asks by worktree. Written back
  /// only when something moved, so a tick where nobody committed does not
  /// re-render the sidebar.
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

  /// What a refresh found gone: a worktree removed in a terminal, or a
  /// directory deleted by hand. Every writer here only ever answers for a
  /// worktree the workspace has, so nothing else drops these.
  ///
  /// Paths are ids. A worktree created at a path one was removed from would
  /// otherwise inherit its badge and its commit date until the next merge
  /// scan answered, which is a merged badge on a branch that has never
  /// landed. `refreshStatuses` filters for the same reason.
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

  /// The menus' Fetch: brings the remote-tracking branches up to date so the
  /// merged badges answer for the remote as it is now, and prunes the
  /// upstreams deleted on a merge. The one git call this app makes that
  /// talks to a network, and only ever on a click.
  ///
  /// A network call is the one thing here that can take long enough to look
  /// broken, so the project is marked for the whole of it, the re-reads that
  /// follow included: the badges are what the user clicked for, and the
  /// fetch alone would stop spinning before they changed.
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

/// What one worktree's merge verdict was computed from, so a refresh that
/// finds all of it where it was asks git nothing more.
///
/// The branch is part of it, not only its tip: `git checkout -b copy` leaves
/// two branches on the same commit, and only one of them may have an
/// upstream that has gone.
///
/// So is whether that upstream was gone, which is the one thing a verdict is
/// drawn from that neither tip records: a first push puts an upstream back
/// under a branch that had none, and a prune takes one away, both without
/// moving either. Left out, the badge that the missing upstream earned would
/// stand until the branch or the trunk next moved.
struct MergeCheck: Equatable, Sendable {
  let base: String
  let baseTip: String
  let branch: String
  let tip: String
  let upstreamIsGone: Bool
}
