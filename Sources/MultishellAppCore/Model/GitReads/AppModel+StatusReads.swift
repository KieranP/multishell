import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A missing project is skipped and a row the pace holds back is queued, see
  /// `StatusReadPace`; nil is every project.
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

  /// Read again at once for the reason `setGitStatusIndicator` gives, and
  /// every file tab with them, a tab counting as its row does.
  public func setDiffAlgorithm(_ algorithm: DiffAlgorithm) {
    store.setDiffAlgorithm(algorithm)
    statusReadLog.invalidate()
    noteEveryFileTabChanged()
    Task { await refreshStatuses() }
  }

  /// A failed read keeps its badge; a gone worktree's goes. A row being read is
  /// left to that read, and one the pace holds back is queued, not dropped.
  func refreshStatuses(where included: (Worktree) -> Bool) async {
    guard let coordinator else { return }
    let now = ContinuousClock.now
    let onSidebar = sidebarRowIDs()
    let wanted = workspace.worktrees.filter { worktree in
      included(worktree) && mayReadStatus(of: worktree)
        && isStatusWanted(worktree, onSidebar: onSidebar)
        && !statusReadLog.isReading(worktree.id)
    }
    for worktree in wanted where !statusReadLog.isDue(worktree.id, at: now) {
      scheduleStatusRefresh(of: worktree.id)
    }
    let readings = await readStatuses(
      of: wanted.filter { statusReadLog.isDue($0.id, at: now) },
      with: coordinator,
    )
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
    of worktrees: [Worktree],
    with coordinator: WorktreeCoordinator,
  ) async -> [Worktree.ID: StatusReading] {
    let ticket = statusReadLog.begin(worktrees.map(\.id))
    let readings = await coordinator.readStatuses(
      of: worktrees,
      counting: workspace.gitStatusIndicator,
      diffAlgorithm: workspace.diffAlgorithm,
    )
    let stillCounts = statusReadLog.finish(ticket)
    let again = statusReadLog.takeAskedAgain(of: ticket)
    for id in again { scheduleStatusRefresh(of: id) }
    guard stillCounts else { return [:] }
    return readings
  }

  /// Where a status read's branch disagrees with the row, re-read that project:
  /// a share whose changes no file event reports is caught here.
  func refreshWorktreesWhoseBranchMoved(_ fresh: [Worktree.ID: WorktreeStatus]) async {
    var drifted: Set<Project.ID> = []
    for worktree in workspace.worktrees {
      if let status = fresh[worktree.id], status.branch != worktree.branch {
        drifted.insert(worktree.projectID)
      }
    }
    await refreshWorktrees(ofProjects: drifted)
  }
}
