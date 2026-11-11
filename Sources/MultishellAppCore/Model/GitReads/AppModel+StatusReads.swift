import MultishellCore
import MultishellGitKit

extension AppModel {
  /// A missing project is skipped and a row the pace holds back is queued, see
  /// `StatusReadPace`; nil is every project.
  func refreshStatuses(inProject id: Project.ID? = nil) async {
    await refreshStatuses { id == nil || $0.projectID == id }
  }

  /// A branch with no upstream counts ↑ past the base, which the first scan
  /// resolves after launch's reads. A row not yet read may have a read under way without it.
  func scheduleStatusRefreshesCountingAhead(past bases: [DefaultBranch], inProject id: Project.ID) {
    let candidates = workspace.worktrees(of: id).filter { worktree in
      statuses[worktree.id].map { status in bases.contains(where: status.countsAhead(past:)) }
        ?? true
    }
    guard !candidates.isEmpty else { return }
    let onSidebar = sidebarRowIDs()
    for worktree in candidates
    where mayReadStatus(of: worktree) && isStatusWanted(worktree, onSidebar: onSidebar) {
      scheduleStatusRefresh(of: worktree.id)
    }
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
    // An image has no diff for the algorithm to change.
    noteFileTabsChanged(releasingDots: false) { !holdsImage($0.id) }
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
    let (readings, _) = await readStatuses(
      of: wanted.filter { statusReadLog.isDue($0.id, at: now) },
      with: coordinator,
    )
    // After the await: a removed row keeps no badge, and one a stage began on
    // meanwhile keeps its old one and takes no new one; see worktrees/creating-and-removing.md.
    let known = Set(workspace.worktrees.map(\.id).filter { !pathClaims.isClaimed($0) })
    let current = workspace.worktrees.keyedByID()
    let kept = readings.filter { current[$0.key].map(mayReadStatus) == true }
    statusReadLog.remember(kept.mapValues(\.duration))
    let fresh = kept.mapValues(\.status)
    for id in fresh.keys { noteDirectoryPresent(of: id) }
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh) { _, new in new }
    setIfChanged(\.statuses, merged)
    await noteStatusesLanded(fresh)
  }

  /// Whether git may be asked about this worktree's status, and whether an
  /// answer may land: both reads ask it before and after git runs.
  func mayReadStatus(of worktree: Worktree) -> Bool {
    !isBeingWritten(worktree) && !missingProjects.contains(worktree.projectID)
  }

  /// Only rows on screen are polled, bar the main one, the selected one and any
  /// on the board; see Docs/design/worktrees/watching-and-status-reads.md.
  func isStatusWanted(_ worktree: Worktree, onSidebar: Set<Worktree.ID>) -> Bool {
    worktree.isPrimary || worktree.id == workspace.selectedWorktreeID
      || onSidebar.contains(worktree.id)
      || (showsAgentBoard
        && workspace.sessions(in: worktree.id).contains { liveSessionIDs.contains($0.id) })
  }

  /// The readings that count, and the rows a later read answered first.
  func readStatuses(
    of worktrees: [Worktree],
    with coordinator: WorktreeCoordinator,
  ) async -> (readings: [Worktree.ID: StatusReading], overtaken: Set<Worktree.ID>) {
    let ticket = statusReadLog.begin(worktrees.map(\.id))
    let readings = await coordinator.readStatuses(
      of: worktrees,
      counting: workspace.gitStatusIndicator,
      diffAlgorithm: workspace.diffAlgorithm,
      bases: defaultBranchScans.compactMapValues(\.branch),
    )
    let counted = statusReadLog.finish(ticket, answered: Set(readings.keys))
    let again = statusReadLog.takeAskedAgain(of: ticket)
    for id in again { scheduleStatusRefresh(of: id) }
    return (readings.filter { counted.contains($0.key) }, statusReadLog.overtaken(ticket))
  }

  /// What every status read's landing sets off, from the poll or one worktree's.
  func noteStatusesLanded(_ fresh: [Worktree.ID: WorktreeStatus]) async {
    // Even one that moved no count: an edit can change the diff since the base alone.
    for id in fresh.keys { scheduleBranchChangesRead(of: id) }
    await refreshWorktreesWhoseBranchMoved(fresh)
  }

  /// Where a status read's branch disagrees with the row, re-read that project:
  /// a share whose changes no file event reports is caught here.
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
