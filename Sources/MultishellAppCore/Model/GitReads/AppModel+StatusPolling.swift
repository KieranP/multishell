import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Working-tree edits do not touch `.git`, so poll instead, and only while
  /// frontmost: a background app running `git status` is noise.
  func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: self?.statusReads.pace.interval ?? .seconds(5))
        guard let self else { return }
        guard platform.isActive else { continue }
        await pollRound()
      }
    }
  }

  func pollRound() async {
    await refreshProjectsWithUnfinishedAdds()
    await refreshStatuses()
    await refreshMergeStates()
    await refreshSharedSettingsIfChanged()
  }

  /// Missing projects and slow worktrees are skipped, see `StatusPollPace`; nil is every project.
  func refreshStatuses(inProject project: Project.ID? = nil) async {
    await refreshStatuses { project == nil || $0.projectID == project }
  }

  /// A failed read keeps its badge rather than blinking off; a gone worktree's
  /// goes. A row already being read is left to that read.
  func refreshStatuses(where included: (Worktree) -> Bool) async {
    guard let coordinator else { return }
    let now = ContinuousClock.now
    let onSidebar = sidebarRowIDs()
    let readings = await readStatuses(
      of: workspace.worktrees.filter { worktree in
        included(worktree) && mayReadStatus(of: worktree)
          && isStatusWanted(worktree, onSidebar: onSidebar)
          && statusReads.isDue(worktree.id, at: now) && !statusReads.isReading(worktree.id)
      }, with: coordinator)
    // After the await: a removed row keeps no badge, and one a stage began on
    // meanwhile keeps its old one and takes no new one; see worktrees.md.
    let known = Set(workspace.worktrees.map(\.id).filter { !pathClaims.isClaimed($0) })
    let current = workspace.worktrees.keyedByID()
    let kept = readings.filter { current[$0.key].map(mayReadStatus) == true }
    statusReads.remember(kept.mapValues(\.took))
    let fresh = kept.mapValues(\.status)
    for id in fresh.keys { noteDirectoryPresent(of: id) }
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh) { _, new in new }
    setIfChanged(\.statuses, merged)
    await refreshProjectsWhoseBranchMoved(fresh)
  }

  /// Whether git may be asked about this worktree's status, and whether an
  /// answer may land: both reads ask it before and after git runs.
  func mayReadStatus(of worktree: Worktree) -> Bool {
    !isBeingWritten(worktree) && !missingProjects.contains(worktree.projectID)
  }

  /// Only rows on screen are polled, bar the main one, the selected one and any
  /// on the board; see Docs/design/worktrees.md.
  func isStatusWanted(_ worktree: Worktree, onSidebar: Set<Worktree.ID>) -> Bool {
    worktree.isPrimary || worktree.id == workspace.selectedWorktreeID
      || onSidebar.contains(worktree.id)
      || (showsAgentBoard
        && workspace.sessions(in: worktree.id).contains { liveSessionIDs.contains($0.id) })
  }

  func readStatuses(
    of worktrees: [Worktree], with coordinator: WorktreeCoordinator
  ) async -> [Worktree.ID: StatusReading] {
    let ticket = statusReads.begin(worktrees.map(\.id))
    let readings = await coordinator.readStatuses(
      of: worktrees, counting: workspace.gitStatusIndicator)
    let stillCounts = statusReads.finish(ticket)
    let again = statusReads.takeAskedAgain(of: ticket)
    if !again.isEmpty {
      // Past the pace, which the read just landed would otherwise hold them to.
      Task { [weak self] in
        for id in again { await self?.refreshStatus(of: id, forced: true) }
      }
    }
    guard stillCounts else { return [:] }
    return readings
  }

  /// An add that died leaves git's mark with nothing in the records changing,
  /// so the list is read again each round, where the lock's age is judged.
  private func refreshProjectsWithUnfinishedAdds() async {
    let marked = Set(workspace.worktrees.filter(\.isInitializing).map(\.projectID))
    await refreshWorktrees(ofProjects: marked.lazy.filter { !self.missingProjects.contains($0) })
  }

  /// A `git checkout` in the main worktree touches `.git/HEAD`, which is not
  /// watched. Where the poll's branch disagrees, re-read that project.
  private func refreshProjectsWhoseBranchMoved(_ fresh: [Worktree.ID: WorktreeStatus]) async {
    var drifted: Set<Project.ID> = []
    for worktree in workspace.worktrees {
      if let status = fresh[worktree.id], status.branch != worktree.branch {
        drifted.insert(worktree.projectID)
      }
    }
    await refreshWorktrees(ofProjects: drifted)
  }

  private func refreshWorktrees(ofProjects ids: some Sequence<Project.ID>) async {
    for id in ids {
      if let project = workspace.project(id) { await refreshWorktrees(of: project) }
    }
  }
}
