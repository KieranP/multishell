import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Missing projects and slow worktrees are skipped, see `StatusPollPace`; nil is every project.
  func refreshStatuses(inProject id: Project.ID? = nil) async {
    await refreshStatuses { id == nil || $0.projectID == id }
  }

  /// Every badge is re-read at once rather than at the next poll, which a
  /// slow checkout paces minutes out: the setting was changed to be seen.
  public func setGitStatusIndicator(_ indicator: GitStatusIndicator) {
    store.setGitStatusIndicator(indicator)
    statusReadLog.invalidate()
    Task { await refreshStatuses() }
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
          && statusReadLog.isDue(worktree.id, at: now) && !statusReadLog.isReading(worktree.id)
      }, with: coordinator)
    // After the await: a removed row keeps no badge, and one a stage began on
    // meanwhile keeps its old one and takes no new one; see worktrees.md.
    let known = Set(workspace.worktrees.map(\.id).filter { !pathClaims.isClaimed($0) })
    let current = workspace.worktrees.keyedByID()
    let kept = readings.filter { current[$0.key].map(mayReadStatus) == true }
    statusReadLog.remember(kept.mapValues(\.duration))
    let fresh = kept.mapValues(\.status)
    for id in fresh.keys { noteDirectoryPresent(of: id) }
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh) { _, new in new }
    setIfChanged(\.statuses, merged)
    await refreshWorktreesWhoseBranchMoved(fresh)
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
    let ticket = statusReadLog.begin(worktrees.map(\.id))
    let readings = await coordinator.readStatuses(
      of: worktrees, counting: workspace.gitStatusIndicator)
    let stillCounts = statusReadLog.finish(ticket)
    let again = statusReadLog.takeAskedAgain(of: ticket)
    if !again.isEmpty {
      // Past the pace, which the read just landed would otherwise hold them to.
      Task { [weak self] in
        for id in again { await self?.refreshStatus(of: id, forced: true) }
      }
    }
    guard stillCounts else { return [:] }
    return readings
  }

  /// A `git checkout` in the main worktree touches `.git/HEAD`, which is not
  /// watched. Where the poll's branch disagrees, re-read that project.
  private func refreshWorktreesWhoseBranchMoved(_ fresh: [Worktree.ID: WorktreeStatus]) async {
    var drifted: Set<Project.ID> = []
    for worktree in workspace.worktrees {
      if let status = fresh[worktree.id], status.branch != worktree.branch {
        drifted.insert(worktree.projectID)
      }
    }
    await refreshWorktrees(ofProjects: drifted)
  }
}
