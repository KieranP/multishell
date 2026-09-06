import Foundation
import MultishellCore
import MultishellProcess

// MARK: - Session state

extension AppModel {
  /// Opens the inbound channel. A failure is reported once and the app runs
  /// without reports: a second instance holding the socket is the usual
  /// cause, and its dots are the ones that will move.
  public func startStateSource() {
    do {
      try stateSource.start()
    } catch {
      report(error)
    }
  }

  /// On quit: the last save, and the socket file unlinked so the next
  /// launch does not have to probe it.
  public func shutDown() {
    saveNow()
    stateSource.stop()
  }

  /// A report names a live session, or only a directory. One with a session
  /// the app does not know is dropped, not matched by its directory: the
  /// channel is trusted to change a dot, and no further than the tab it
  /// can prove it belongs to.
  public func apply(_ report: SessionStateReport) {
    if let id = report.sessionID {
      guard liveSessions.contains(id), let session = workspace.session(id) else { return }
      let shown = isShown(id)
      mutateStates { $0.report(report.state, pid: report.pid, for: .session(id), isShown: shown) }
      notifyIfNeeded(report, key: .session(id), worktreeID: session.worktreeID, isShown: shown)
    } else if let cwd = report.cwd, let worktree = worktree(atPath: cwd) {
      let shown = workspace.selectedWorktreeID == worktree.id
      mutateStates {
        $0.report(report.state, pid: report.pid, for: .worktree(worktree.id), isShown: shown)
      }
      notifyIfNeeded(report, key: .worktree(worktree.id), worktreeID: worktree.id, isShown: shown)
    }
    updatePIDWatch()
  }

  /// The pane is on screen: its worktree is selected and its tab active.
  public func isShown(_ id: TerminalSession.ID) -> Bool {
    guard let worktree = workspace.selectedWorktreeID, let tab = workspace.activeTab(in: worktree)
    else { return false }
    return tab.root.contains(id)
  }

  /// A hook's `cwd` may be the resolved path where the worktree was added
  /// through a symlink, so both spellings are tried.
  public func worktree(atPath path: String) -> Worktree? {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    let candidates = Set([url.standardizedFileURL.path, url.resolvingSymlinksInPath().path])
    return workspace.worktrees.first { worktree in
      candidates.contains(worktree.path.path)
        || candidates.contains(worktree.path.resolvingSymlinksInPath().path)
    }
  }

  private func notifyIfNeeded(
    _ report: SessionStateReport, key: SessionStates.Key, worktreeID: Worktree.ID, isShown: Bool
  ) {
    guard
      NotificationPolicy.shouldNotify(
        report.state, preference: workspace.notifications, isShown: isShown,
        appIsActive: platform.isActive, duration: report.duration),
      let worktree = workspace.worktree(worktreeID)
    else { return }
    let project = workspace.project(worktree.projectID)?.name ?? ""
    // The name the user gave the worktree, where they gave one: a
    // notification arrives with the app off screen, and the sidebar they
    // are picturing says that, not the branch.
    let place = workspace.displayName(of: worktree)
    let subject: String
    if case .session(let id) = key, let tab = workspace.tabOwning(id) {
      subject = title(of: tab)
    } else {
      subject = place
    }
    notifier.notify(
      title: NotificationPolicy.title(subject: subject, project: project, worktree: place),
      body: NotificationPolicy.body(for: report.state, message: report.message),
      about: key)
  }

  /// A click on the notification: bring the tab, or the worktree, on screen.
  public func reveal(_ key: SessionStates.Key) {
    switch key {
    case .session(let id):
      guard let tab = workspace.tabOwning(id), let worktree = workspace.worktree(tab.worktreeID)
      else { return }
      select(worktree)
      activate(tab)
    case .worktree(let id):
      if let worktree = workspace.worktree(id) { select(worktree) }
    }
  }

  // MARK: Engine signals

  func noteCommandFinished(in id: TerminalSession.ID, exitCode: Int32?) {
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    mutateStates { $0.noteCommandFinished(in: id, exitCode: exitCode, isShown: isShown(id)) }
    updatePIDWatch()
  }

  /// Keys stay a subset of the live shells and the known worktrees.
  func pruneStates() {
    let worktrees = Set(workspace.worktrees.map(\.id))
    mutateStates { $0.retain(sessions: liveSessions, worktrees: worktrees) }
  }

  /// Copy, change, assign if different: one observation per real change,
  /// and none for a report that changed nothing.
  func mutateStates(_ change: (inout SessionStates) -> Void) {
    var changed = sessionStates
    change(&changed)
    if changed != sessionStates { sessionStates = changed }
  }

  // MARK: Queries for views

  public func state(of tab: TerminalTab) -> SessionState? {
    sessionStates.state(ofSessions: tab.sessionIDs)
  }

  public func state(ofWorktree id: Worktree.ID) -> SessionState? {
    sessionStates.state(ofWorktree: id, sessions: workspace.sessions(in: id).map(\.id))
  }

  /// The most urgent of the project's worktrees, for its row while collapsed.
  public func state(ofProject id: Project.ID) -> SessionState? {
    SessionState.mostUrgent(workspace.worktrees(of: id).compactMap { state(ofWorktree: $0.id) })
  }

  /// Agents that reported Working, counted separately by the quit guard.
  public var workingAgentCount: Int { sessionStates.workingSessionCount }

  public func clearState(of tab: TerminalTab) {
    mutateStates { $0.clear(sessions: tab.sessionIDs, worktree: nil) }
    updatePIDWatch()
  }

  public func clearState(ofWorktree id: Worktree.ID) {
    mutateStates { $0.clear(sessions: workspace.sessions(in: id).map(\.id), worktree: id) }
    updatePIDWatch()
  }

  // MARK: Stale Working

  /// An agent killed with Ctrl+C sends no Stop hook. The app cannot see it
  /// exit, so while any state names a pid the pid is checked on a timer and
  /// its state dropped once the process is gone. No timeout: a long task is
  /// not a stale one.
  func updatePIDWatch() {
    guard !sessionStates.trackedPIDs.isEmpty else {
      pidWatch?.cancel()
      pidWatch = nil
      return
    }
    guard pidWatch == nil else { return }
    pidWatch = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        guard let self else { return }
        try? await Task.sleep(for: pidPollInterval)
        guard !Task.isCancelled else { return }
        for pid in sessionStates.trackedPIDs where ProcessAncestry.isGone(pid) {
          mutateStates { $0.processGone(pid) }
        }
        if sessionStates.trackedPIDs.isEmpty {
          pidWatch = nil
          return
        }
      }
    }
  }
}
