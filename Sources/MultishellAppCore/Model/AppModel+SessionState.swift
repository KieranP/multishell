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
      // Gated on the board for the same reason `isShown` is: the worktree is
      // selected, but nothing of it is on screen. And on frontmost for the
      // reason `hasBeenSeen` is.
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

  /// Seen: on screen and the app in front of the user. The one notion a
  /// Done clears against and a banner is raised against, so the dot and the
  /// banner can never disagree about whether anyone looked. A pane can be
  /// the shown one for hours with its window behind another app.
  public func hasBeenSeen(_ id: TerminalSession.ID) -> Bool {
    isShown(id) && platform.isActive
  }

  /// The pane is on screen: its worktree is selected and its tab is the one
  /// its column shows. A worktree can have several columns, so this asks
  /// every one of them rather than the focused column alone — a pane in the
  /// next column over is on screen too. Half of `hasBeenSeen`, and on its
  /// own it says nothing about whether the user is at the machine.
  public func isShown(_ id: TerminalSession.ID) -> Bool {
    // The board fills the detail area, so no pane is on screen behind it.
    // Without this the selected worktree's Done states clear the moment the
    // board opens and their cards sit in Idle having never passed through
    // Done, so nothing would ever say that a pane had finished.
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
    notifiedKeys.insert(key)
  }

  /// Takes a banner back, where the key has one. Called where what it said
  /// has stopped being true: the state moved on, or the user brought the
  /// pane up. A pane's dot is not touched, a question the user has seen but
  /// not answered still being a question; what goes is the interruption.
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

  /// Keys stay a subset of the live shells and the known worktrees. The
  /// banner keys need no sweep of their own: a key is only ever notified
  /// about while it holds a state, `sessionStates` is assigned in one place,
  /// and that place takes the banner back for any key whose state moved, so
  /// dropping the state here drops the banner with it.
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
    // were posted about. A report that moves a key on is followed by its own
    // notify where the new state deserves one.
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
  /// clear beside it in the same menu takes every pane at once; this takes
  /// the one the card is about.
  public func clearState(ofSession id: TerminalSession.ID) {
    mutateStates { $0.clear(.session(id)) }
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

  /// The pids worth a poll.
  ///
  /// The ones a state is about, always: a Working dot must not outlive its
  /// process wherever the user happens to be looking. The ones an agent
  /// reported itself under, only while the board is up, which is the one
  /// place a quit agent shows as anything — a file dropped on a pane asks
  /// `ReportedAgent.isAtThePrompt` at the moment of the drop instead. The
  /// board sweeps once as it opens, so its first frame is not stale. Cost
  /// avoided: a two-second timer running for as long as any agent has ever
  /// reported, rather than while anything is being said about one.
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
