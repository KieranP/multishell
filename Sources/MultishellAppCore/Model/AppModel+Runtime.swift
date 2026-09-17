import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Brings the host in line with the store. Every action that changes which
  /// terminals exist ends here; only a user's own action takes the keyboard.
  public func reconcileSessions(takingFocus: Bool) {
    reconcile()
    guard takingFocus else { return }
    // The keyboard is a pane's now, whatever field held it.
    findFieldPane = nil
    registry.focusActiveSession()
    markFocusedPaneSeen()
  }

  /// For a control that is leaving, such as the sidebar filter on Escape: the
  /// keyboard would otherwise fall to the window and type into nothing.
  public func focusActivePane() {
    guard !showsAgentBoard else { return }
    registry.focusActiveSession()
  }

  /// Surfaces brought in line with the workspace, the keyboard left alone: a
  /// poll reaches this too, and focusing would take it off a field being typed in.
  private func reconcile() {
    let warm = warmWorktrees
    let failures = registry.reconcile(
      shouldBeLive: { warm.contains($0.worktreeID) }, prepare: { prepared($0) })
    for (index, failure) in failures.enumerated() {
      // One alert slot: four sessions failing at once would otherwise leave
      // one message about the last of them and nothing about the rest.
      if index == 0 {
        report(failure.error)
      } else {
        platform.log("a session could not be opened: \(failure.error)")
      }
      store.closeSession(failure.sessionID)
    }
    pruneStates()
    prunePendingClose()
    pruneFind()
  }

  /// The focused pane and the selected worktree are seen; every pane in view
  /// loses its banner. Guarded on the board and frontmost, as `hasBeenSeen` is.
  func markFocusedPaneSeen() {
    guard platform.isActive, !showsAgentBoard, let worktree = workspace.selectedWorktreeID
    else { return }
    let focused = workspace.activeTab(in: worktree).map { [$0.focusedSessionID] } ?? []
    if sessionStates.hasAnythingToSee(sessions: focused, worktree: worktree) {
      mutateStates { $0.markSeen(sessions: focused, worktree: worktree) }
    }
    guard !notifiedKeys.isEmpty else { return }
    for id in workspace.shownTabs(in: worktree).flatMap(\.sessionIDs) {
      withdrawNotification(about: .session(id))
    }
    withdrawNotification(about: .worktree(worktree))
  }

  public func report(_ error: any Error) {
    presentedError = PresentedError(error)
  }
}

extension AppModel {
  /// For the polling paths' reads and the Trash. Microseconds on a local
  /// disk; on a dead mount each blocks until it times out.
  nonisolated static func offMain<T: Sendable>(_ work: @Sendable @escaping () -> T) async -> T {
    await Task.detached(priority: .utility) { work() }.value
  }

  /// Writes only where the value differs: an observed write redraws every
  /// view reading it, and most of these land on a timer. `true` where it wrote.
  @discardableResult
  func setIfChanged<T: Equatable>(
    _ path: ReferenceWritableKeyPath<AppModel, T>, _ value: T
  )
    -> Bool
  {
    guard self[keyPath: path] != value else { return false }
    self[keyPath: path] = value
    return true
  }

  /// The one place per-worktree runtime state is dropped, fed with what the
  /// store discarded. Paths are ids, so a worktree re-made there starts clean.
  func forgetWorktrees(_ ids: [Worktree.ID]) {
    guard !ids.isEmpty else { return }
    let gone = Set(ids)
    setIfChanged(\.statuses, statuses.filter { !gone.contains($0.key) })
    setIfChanged(\.mergeStates, mergeStates.filter { !gone.contains($0.key) })
    setIfChanged(\.lastCommits, lastCommits.filter { !gone.contains($0.key) })
    mergeChecks = mergeChecks.filter { !gone.contains($0.key) }
    statusReads = statusReads.filter { !gone.contains($0.key) }
    for id in ids {
      // A stage still running has no pane left to Cancel from, so it is ended
      // as that Cancel would end it; its task lets go of these as it returns.
      stageStoppers[id]?.stop()
      worktreeOperations.clear(id)
      pendingStatusRefreshes[id]?.cancel()
      pendingStatusRefreshes[id] = nil
    }
    if let renaming = renamingWorktreeID, gone.contains(renaming) { renamingWorktreeID = nil }
    if let pending = pendingRemoval, gone.contains(pending.worktree.id) { pendingRemoval = nil }
  }
}

extension AppModel {
  /// Working-tree edits do not touch `.git`, so poll instead, and only while
  /// frontmost: a background app running `git status` is noise.
  public func startStatusPolling() {
    statusPolling?.cancel()
    statusPolling = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: self?.statusPace.interval ?? .seconds(5))
        guard let self else { return }
        guard platform.isActive else { continue }
        await refreshStatuses()
        await refreshMergeStates()
        await refreshChangedSharedSettings()
      }
    }
  }

  /// A read that failed keeps its last badge rather than blinking off; a gone
  /// worktree loses it. Missing and slow projects are skipped; see `StatusPollPace`.
  public func refreshStatuses() async {
    guard let worktrees else { return }
    let now = ContinuousClock.now
    let fresh = await readStatuses(
      of: workspace.worktrees.filter { worktree in
        !isUnderConstruction(worktree.id) && !missingProjects.contains(worktree.projectID)
          && statusPace.isDue(
            lastRead: statusReads[worktree.id]?.at, took: statusReads[worktree.id]?.took, at: now)
      }, with: worktrees)
    // Read after the await, and applied to what git returned as well as to
    // what was there: a removed row keeps no badge; see worktrees.md.
    let known = Set(workspace.worktrees.map(\.id).filter { creatingWorktreeClaims[$0] == nil })
    var merged = statuses.filter { known.contains($0.key) }
    merged.merge(fresh.filter { known.contains($0.key) }) { _, new in new }
    setIfChanged(\.statuses, merged)
    await refreshProjectsWhoseBranchMoved(fresh)
  }

  /// Every read's cost is remembered, so the poll can leave a slow checkout
  /// alone for a while; a read that failed says nothing about the next.
  private func readStatuses(
    of worktrees: [Worktree], with coordinator: WorktreeCoordinator
  ) async -> [Worktree.ID: WorktreeStatus] {
    let readings = await coordinator.readStatuses(of: worktrees)
    let finished = ContinuousClock.now
    for (id, reading) in readings { statusReads[id] = (finished, reading.took) }
    return readings.mapValues(\.status)
  }

  /// A `git checkout` in the main worktree touches `.git/HEAD`, which is not
  /// watched. Where the poll's branch disagrees, re-read that project.
  func refreshProjectsWhoseBranchMoved(_ fresh: [Worktree.ID: WorktreeStatus]) async {
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

  public func refreshStatus(of worktreeID: Worktree.ID) async {
    guard let worktrees, let worktree = workspace.worktree(worktreeID),
      !isUnderConstruction(worktreeID)
    else { return }
    let fresh = await readStatuses(of: [worktree], with: worktrees)
    // Gone while git ran: paths are ids, so a worktree re-made at this path
    // would otherwise wear the old checkout's badge until the next poll.
    guard workspace.worktree(worktreeID) != nil, !isUnderConstruction(worktreeID) else { return }
    if let status = fresh[worktreeID] { setIfChanged(\.statuses[worktreeID], status) }
  }
}

extension AppModel {
  /// Activity in the pane with the keyboard is being watched; anywhere else,
  /// a split's other pane included, it is remembered until that pane is focused.
  func noteActivity(in id: TerminalSession.ID) {
    // A prompt or a finished command in this worktree likely changed its
    // status, so look soon rather than waiting for the next poll.
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    mutateStates { $0.noteActivity(in: id, isSeen: hasBeenSeen(id)) }
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

  func noteTitle(_ title: String, of id: TerminalSession.ID) {
    setIfChanged(\.sessionTitles[id], title)
  }

  /// What the tab strip shows: the user's name, else what the shell last
  /// reported, else the tab's starting title.
  public func title(of tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[tab.focusedSessionID] ?? workspace.title(of: tab)
  }

  /// One pane's, a split holding several: the user's name for the tab, else
  /// what this pane's shell last reported, else its starting title.
  public func title(ofPane session: TerminalSession, in tab: TerminalTab) -> String {
    tab.customTitle ?? sessionTitles[session.id] ?? session.title
  }
}
