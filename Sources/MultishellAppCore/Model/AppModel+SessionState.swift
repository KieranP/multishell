import Foundation
import MultishellCore
import MultishellProcess

// MARK: - Session state

extension AppModel {
  /// Opens the inbound channel, a failure reported once. A second instance
  /// holding the socket is the usual cause.
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

  /// A report names a live session, or only a directory. One naming an
  /// unknown session is dropped, never matched by directory.
  public func apply(_ report: SessionStateReport) {
    if let id = report.sessionID {
      guard liveSessions.contains(id), let session = workspace.session(id) else { return }
      // Who is at that prompt, for a drop on it to be written as that agent
      // reads a file. A dot is all this changes about the pane itself.
      if let agent = report.agent {
        reportedAgents[id] = ReportedAgent(agentID: agent, pid: report.pid)
      }
      let seen = hasBeenSeen(id)
      mutateStates {
        $0.report(
          report.state, pid: report.pid, message: report.message, duration: report.duration,
          for: .session(id), isSeen: seen)
      }
      notifyIfNeeded(report, key: .session(id), worktreeID: session.worktreeID, isSeen: seen)
    } else if let cwd = report.cwd, let worktree = worktree(atPath: cwd) {
      // Gated on the board as `isShown` is, the worktree being selected
      // with nothing of it on screen; and on frontmost as `hasBeenSeen`.
      let seen =
        !showsAgentBoard && workspace.selectedWorktreeID == worktree.id && platform.isActive
      mutateStates {
        $0.report(
          report.state, pid: report.pid, message: report.message, duration: report.duration,
          for: .worktree(worktree.id), isSeen: seen)
      }
      notifyIfNeeded(report, key: .worktree(worktree.id), worktreeID: worktree.id, isSeen: seen)
    }
    updatePIDWatch()
  }

  /// Seen: on screen and the app in front. One notion for clearing a Done
  /// and raising a banner, so the two can never disagree.
  public func hasBeenSeen(_ id: TerminalSession.ID) -> Bool {
    isShown(id) && platform.isActive
  }

  /// The pane is on screen: its worktree selected and its tab shown, asked
  /// of every column. Half of `hasBeenSeen`, saying nothing about the user.
  public func isShown(_ id: TerminalSession.ID) -> Bool {
    // The board fills the detail area, so no pane is on screen behind it,
    // and a card would reach Idle having never passed through Done.
    guard !showsAgentBoard, let worktree = workspace.selectedWorktreeID else { return false }
    return workspace.shownTabs(in: worktree).contains { $0.root.contains(id) }
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
    _ report: SessionStateReport, key: SessionStates.Key, worktreeID: Worktree.ID, isSeen: Bool
  ) {
    guard
      NotificationPolicy.shouldNotify(
        report.state, preference: workspace.notifications, isSeen: isSeen,
        duration: report.duration, silent: report.silent == true),
      let worktree = workspace.worktree(worktreeID)
    else { return }
    let project = workspace.project(worktree.projectID)?.name ?? ""
    // The name the user gave the worktree: a notification arrives with the
    // app off screen, and the sidebar they picture says that.
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
    notifiedKeys.insert(key)
  }

  /// Takes a banner back where what it said has stopped being true. The dot
  /// is not touched; what goes is the interruption.
  func withdrawNotification(about key: SessionStates.Key) {
    guard notifiedKeys.remove(key) != nil else { return }
    notifier.withdraw(about: key)
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
    mutateStates { $0.noteCommandFinished(in: id, exitCode: exitCode, isSeen: hasBeenSeen(id)) }
    updatePIDWatch()
  }

  /// Keys stay a subset of the live shells and known worktrees. The banners
  /// need no sweep: dropping a state here drops its banner with it.
  func pruneStates() {
    let worktrees = Set(workspace.worktrees.map(\.id))
    mutateStates { $0.retain(sessions: liveSessions, worktrees: worktrees) }
  }

  /// Copy, change, assign if different: one observation per real change,
  /// and none for a report that changed nothing.
  func mutateStates(_ change: (inout SessionStates) -> Void) {
    var changed = sessionStates
    change(&changed)
    // The one place a clock reaches the states, so `SessionStates` itself
    // stays testable without one.
    changed.stampChanges(against: sessionStates, at: Date())
    guard changed != sessionStates else { return }
    // Before the assignment, so the comparison is against what the banners
    // were posted about.
    let moved = notifiedKeys.filter { changed[$0] != sessionStates[$0] }
    sessionStates = changed
    for key in moved { withdrawNotification(about: key) }
    updateDockBadge()
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

  /// One pane's own dot, for a card whose agent is long gone. The worktree's
  /// clear beside it takes every pane at once.
  public func clearState(ofSession id: TerminalSession.ID) {
    mutateStates { $0.clear(.session(id)) }
    updatePIDWatch()
  }

  public func clearState(ofWorktree id: Worktree.ID) {
    mutateStates { $0.clear(sessions: workspace.sessions(in: id).map(\.id), worktree: id) }
    updatePIDWatch()
  }

  // MARK: Stale Working

  /// An agent killed with Ctrl+C sends no Stop hook, so a named pid is
  /// polled and its state dropped once gone. No timeout.
  func updatePIDWatch() {
    guard !watchedPIDs.isEmpty else {
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
        sweepGonePIDs()
        if watchedPIDs.isEmpty {
          pidWatch = nil
          return
        }
      }
    }
  }

  /// The pids worth a poll: those a state is about always, and those an
  /// agent reported under only while the board is up; see agents.md.
  var watchedPIDs: Set<Int32> {
    guard showsAgentBoard else { return sessionStates.trackedPIDs }
    return sessionStates.trackedPIDs.union(reportedAgents.values.compactMap(\.pid))
  }

  /// One pass over them. A state whose process has gone loses the claim it
  /// was making; a pane whose agent has gone is a plain shell again.
  func sweepGonePIDs() {
    for pid in watchedPIDs where ProcessAncestry.isGone(pid) {
      mutateStates { $0.processGone(pid) }
      dropReportedAgents(withPID: pid)
    }
  }

  private func dropReportedAgents(withPID pid: Int32) {
    let remaining = reportedAgents.filter { $0.value.pid != pid }
    guard remaining.count != reportedAgents.count else { return }
    reportedAgents = remaining
    updateDockBadge()
  }
}
