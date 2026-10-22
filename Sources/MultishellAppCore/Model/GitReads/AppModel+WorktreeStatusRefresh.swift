import MultishellCore
import MultishellGitKit

extension AppModel {
  /// `forced` is a read someone asked for, past the pace; see worktrees.md.
  /// `true` where a status landed.
  @discardableResult
  func refreshStatus(of worktreeID: Worktree.ID, forced: Bool = false) async -> Bool {
    guard let coordinator, let worktree = workspace.worktree(worktreeID),
      mayReadStatus(of: worktree)
    else { return false }
    if !forced, statusReadLog.isReading(worktreeID) {
      statusReadLog.askAgain(worktreeID)
      return false
    }
    guard forced || statusReadLog.isDue(worktreeID, at: .now) else { return false }
    let readings = await readStatuses(of: [worktree], with: coordinator)
    // Gone while git ran: paths are ids, so a worktree re-made at this path
    // would otherwise wear the old checkout's badge until the next poll.
    guard let still = workspace.worktree(worktreeID), mayReadStatus(of: still) else {
      return false
    }
    statusReadLog.remember(readings.mapValues(\.duration))
    guard let reading = readings[worktreeID] else { return false }
    noteDirectoryPresent(of: worktreeID)
    setIfChanged(\.statuses[worktreeID], reading.status)
    await refreshWorktreesWhoseBranchMoved([worktreeID: reading.status])
    return true
  }

  /// Nothing writes there now, so read rather than wait out the poll. Judged
  /// when the read runs: `endSetup` is called before a file list's entry clears.
  func scheduleBadgeRefresh(of id: Worktree.ID, in projectID: Project.ID) {
    scheduleStatusRefresh(of: id)
    Task { @MainActor [weak self] in
      guard let self, !isBeingWritten(id), let project = workspace.project(projectID)
      else { return }
      await refreshBranchScan(of: project)
    }
  }

  /// A project just listed, added or refreshed on request: no file event brings
  /// its rows' badges, and the round is a minute off.
  func refreshBadges(ofProject id: Project.ID) async {
    await refreshStatuses(inProject: id)
    if let project = workspace.project(id), !missingProjects.contains(id) {
      await refreshBranchScan(of: project)
    }
  }

  /// A burst becomes one read once it settles and the pace allows, never pushed
  /// back by the next change, or a build writing on would hold the badge.
  func scheduleStatusRefresh(of worktreeID: Worktree.ID) {
    guard pendingStatusRefreshes[worktreeID] == nil else { return }
    pendingStatusRefreshes[worktreeID] = Task { @MainActor [weak self] in
      try? await Task.sleep(for: Self.changeSettleDelay)
      // Looped: a forced read begun before the change can land meanwhile and
      // move the pace on, and the read it would then refuse is this change's.
      while !Task.isCancelled, let due = self?.statusReadLog.nextDue(worktreeID), due > .now {
        try? await Task.sleep(until: due)
      }
      guard !Task.isCancelled, let self else { return }
      pendingStatusRefreshes[worktreeID] = nil
      // Left to the read a return to the front makes, bar the panel's.
      guard platform.isActive || readsStatusInTheBackground(worktreeID) else { return }
      await refreshStatus(of: worktreeID)
    }
  }
}
