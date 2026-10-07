import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Paced like the poll; `forced` must start after its cause, see worktrees.md.
  /// `true` where a status landed, which a failed git or a skipped read is not.
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
    return true
  }

  /// Nothing writes there now, so read rather than wait out the poll. Judged
  /// when the read runs: `endSetup` is called before a file list's entry clears.
  func refreshBadges(of id: Worktree.ID, in projectID: Project.ID) {
    scheduleStatusRefresh(of: id)
    Task { @MainActor [weak self] in
      guard let self, !isBeingWritten(id), let project = workspace.project(projectID)
      else { return }
      await refreshBranchScan(of: project)
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
    statusReadLog.invalidate()
    Task { await refreshStatuses() }
  }
}
