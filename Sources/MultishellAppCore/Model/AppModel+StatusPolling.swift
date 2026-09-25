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

  /// Missing and slow projects are skipped, see `StatusPollPace`; nil is every project.
  func refreshStatuses(of project: Project.ID? = nil) async {
    await refreshStatuses { project == nil || $0.projectID == project }
  }

  /// A failed read keeps its badge rather than blinking off; a gone worktree's
  /// goes. A row already being read is left to that read.
  func refreshStatuses(where included: (Worktree) -> Bool) async {
    guard let worktrees else { return }
    let now = ContinuousClock.now
    let onSidebar = sidebarRowIDs()
    let readings = await readStatuses(
      of: workspace.worktrees.filter { worktree in
        included(worktree) && mayReadStatus(of: worktree)
          && isStatusWanted(worktree, onSidebar: onSidebar)
          && statusReads.isDue(worktree.id, at: now) && !statusReads.isReading(worktree.id)
      }, with: worktrees)
    // After the await: a removed row keeps no badge, and one a stage began on
    // meanwhile keeps its old one and takes no new one; see worktrees.md.
    let known = Set(workspace.worktrees.map(\.id).filter { !workInFlight.isClaimed($0) })
    let current = Dictionary(workspace.worktrees.map { ($0.id, $0) }) { first, _ in first }
    let kept = readings.filter { current[$0.key].map(mayReadStatus) == true }
    statusReads.remember(kept.mapValues(\.took))
    let fresh = kept.mapValues(\.status)
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh) { _, new in new }
    setIfChanged(\.statuses, merged)
    await refreshProjectsWhoseBranchMoved(fresh)
  }

  /// Whether git may be asked about this worktree's status, and whether an
  /// answer may land: both reads ask it before and after git runs.
  private func mayReadStatus(of worktree: Worktree) -> Bool {
    !isUnderConstruction(worktree) && !missingProjects.contains(worktree.projectID)
  }

  /// Only rows on screen are polled, bar the main one, the selected one and any
  /// on the board; see Docs/design/worktrees.md.
  private func isStatusWanted(_ worktree: Worktree, onSidebar: Set<Worktree.ID>) -> Bool {
    worktree.isPrimary || worktree.id == workspace.selectedWorktreeID
      || onSidebar.contains(worktree.id)
      || (showsAgentBoard
        && workspace.sessions(in: worktree.id).contains { liveSessions.contains($0.id) })
  }

  /// The rows the sidebar draws, once a round: asked per row, the filter
  /// looked up the project and folded the text for every worktree.
  private func sidebarRowIDs(filteredBy text: String? = nil) -> Set<Worktree.ID> {
    let filter = SidebarFilter(text ?? sidebarFilterText)
    guard !filter.isActive else {
      return Set(filter.apply(to: workspace).flatMap { $0.worktrees.map(\.id) })
    }
    let closed = Set(workspace.projects.filter { !$0.isExpanded }.map(\.id))
    return Set(workspace.worktrees.filter { !closed.contains($0.projectID) }.map(\.id))
  }

  private func polledRowIDs(filteredBy text: String? = nil) -> Set<Worktree.ID> {
    let onSidebar = sidebarRowIDs(filteredBy: text)
    return Set(workspace.worktrees.filter { isStatusWanted($0, onSidebar: onSidebar) }.map(\.id))
  }

  private func readStatuses(
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
    for id in marked where !missingProjects.contains(id) {
      if let project = workspace.project(id) { await refresh(project) }
    }
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
    for id in drifted {
      if let project = workspace.project(id) { await refresh(project) }
    }
  }

  /// Paced like the poll, terminal output arriving in bursts. `forced` is a read
  /// that must start after its cause, a click or a change; see worktrees.md.
  func refreshStatus(of worktreeID: Worktree.ID, forced: Bool = false) async {
    guard let worktrees, let worktree = workspace.worktree(worktreeID),
      mayReadStatus(of: worktree)
    else { return }
    if !forced, statusReads.isReading(worktreeID) {
      return statusReads.askAgain(worktreeID)
    }
    guard forced || statusReads.isDue(worktreeID, at: .now) else { return }
    let readings = await readStatuses(of: [worktree], with: worktrees)
    // Gone while git ran: paths are ids, so a worktree re-made at this path
    // would otherwise wear the old checkout's badge until the next poll.
    guard let still = workspace.worktree(worktreeID), mayReadStatus(of: still) else { return }
    statusReads.remember(readings.mapValues(\.took))
    if let reading = readings[worktreeID] {
      setIfChanged(\.statuses[worktreeID], reading.status)
    }
  }

  /// Rows the filter hid went unread, so those it brings back are read, as
  /// opening a project's are; after a pause, not at every keystroke.
  func scheduleRevealedRowsRead(from oldText: String) {
    let polledBefore =
      pendingRevealedRowsRead?.polledThroughout ?? polledRowIDs(filteredBy: oldText)
    let polledThroughout = polledBefore.intersection(polledRowIDs())
    pendingRevealedRowsRead?.task.cancel()
    let task = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self else { return }
      pendingRevealedRowsRead = nil
      let revealed = polledRowIDs().subtracting(polledThroughout)
      await refreshStatuses { revealed.contains($0.id) }
    }
    pendingRevealedRowsRead = (polledThroughout, task)
  }

  /// Nothing writes there now, so read rather than wait out the poll. Judged
  /// when the read runs: `endSetup` is called before a file list's entry clears.
  func refreshBadges(of id: Worktree.ID, in projectID: Project.ID) {
    scheduleStatusRefresh(of: id)
    Task { @MainActor [weak self] in
      guard let self, !isUnderConstruction(id), let project = workspace.project(projectID)
      else { return }
      await refreshMergeStates(of: project)
    }
  }

  /// One command at a prompt raises several events in a row, each of which
  /// would spawn a `git status`. The burst becomes one run.
  func scheduleStatusRefresh(of worktreeID: Worktree.ID) {
    pendingStatusRefreshes[worktreeID]?.cancel()
    pendingStatusRefreshes[worktreeID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: .milliseconds(250))
      guard !Task.isCancelled, let self else { return }
      pendingStatusRefreshes[worktreeID] = nil
      await refreshStatus(of: worktreeID)
    }
  }

  /// Every badge is re-read at once rather than at the next poll, which a
  /// slow checkout paces minutes out: the setting was changed to be seen.
  public func setGitStatusIndicator(_ indicator: GitStatusIndicator) {
    store.setGitStatusIndicator(indicator)
    statusReads.invalidate()
    Task { await refreshStatuses() }
  }
}
