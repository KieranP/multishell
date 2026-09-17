import Foundation
import MultishellCore
import MultishellProcess

extension AppModel {
  /// Opens the inbound channel. `false` where another copy of this build
  /// holds it: this one hands over to it and quits; see state-and-store.md.
  public func startStateSource() -> Bool {
    do {
      try stateSource.start()
      return true
    } catch let failure as SocketFailure where failure.kind == .inUse {
      yieldingToRunningInstance = true
      pendingSave?.cancel()
      platform.handOverToRunningInstance()
      // Still here: the platform could not quit, so say what is wrong.
      report(failure)
      return false
    } catch {
      report(error)
      return true
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
    // An older helper's walk from a prompt ends at this process, whose pid
    // never goes while it is looking; see docs/design/agents.md.
    let pid = report.pid == ProcessInfo.processInfo.processIdentifier ? nil : report.pid
    if let id = report.sessionID {
      guard liveSessions.contains(id), let session = workspace.session(id) else { return }
      // Who is at that prompt, so a drop is written as that agent reads a file.
      if let agent = report.agent {
        setIfChanged(\.reportedAgents[id], ReportedAgent(agentID: agent, pid: pid))
      }
      apply(
        report, pid: pid, to: .session(id), in: session.worktreeID, isSeen: hasBeenSeen(id),
        isOnScreen: isShown(id) && platform.isActive)
    } else if let cwd = report.cwd, let worktree = worktree(atPath: cwd) {
      // Gated on the board as `isShown` is, the worktree being selected
      // with nothing of it on screen; and on frontmost as `hasBeenSeen`.
      let seen =
        !showsAgentBoard && workspace.selectedWorktreeID == worktree.id && platform.isActive
      apply(
        report, pid: pid, to: .worktree(worktree.id), in: worktree.id, isSeen: seen,
        isOnScreen: seen)
    }
    updatePIDWatch()
  }

  /// `isSeen` is the focused pane and clears a Done; `isOnScreen` is any pane
  /// in view and holds the banner. See docs/design/terminals.md.
  private func apply(
    _ report: SessionStateReport, pid: Int32?, to key: SessionStates.Key,
    in worktreeID: Worktree.ID, isSeen: Bool, isOnScreen: Bool
  ) {
    var meant: SessionState?
    mutateStates {
      meant = $0.report(
        report.state, pid: pid, message: report.message, duration: report.duration,
        subagent: report.subagentChange, startsTurn: report.startsTurn == true, for: key,
        isSeen: isSeen)
    }
    if let meant {
      notifyIfNeeded(report, as: meant, key: key, worktreeID: worktreeID, isSeen: isOnScreen)
    }
  }

  /// Seen: the pane with the keyboard, and the app in front. A split's other
  /// pane is in view but not looked at, so its Done waits for its focus.
  public func hasBeenSeen(_ id: TerminalSession.ID) -> Bool {
    isFocused(id) && platform.isActive
  }

  /// The pane the keyboard goes to: the selected worktree's active tab's
  /// focused pane, with the board hidden. What clears a Done.
  public func isFocused(_ id: TerminalSession.ID) -> Bool {
    guard !showsAgentBoard, let worktree = workspace.selectedWorktreeID else { return false }
    return workspace.activeTab(in: worktree)?.focusedSessionID == id
  }

  /// The pane is on screen: its worktree selected and its tab shown, asked
  /// of every column. What holds a banner back, saying nothing about focus.
  public func isShown(_ id: TerminalSession.ID) -> Bool {
    // The board fills the detail area, so no pane is on screen behind it,
    // and a card would reach Idle having never passed through Done.
    guard !showsAgentBoard, let worktree = workspace.selectedWorktreeID else { return false }
    return workspace.shownTabs(in: worktree).contains { $0.root.contains(id) }
  }

  /// The deepest worktree holding the directory. A hook's `cwd` may be the
  /// resolved path of one added through a symlink, so both spellings are tried.
  public func worktree(atPath path: String) -> Worktree? {
    let url = URL(fileURLWithPath: path, isDirectory: true)
    let spellings = [url.standardizedFileURL, url.resolvingSymlinksInPath()].map(\.pathComponents)
    // Depth is the matching root's, not the written path's: a symlink chain
    // can spell a shallow worktree long.
    let matches = workspace.worktrees.compactMap { worktree -> (Worktree, Int)? in
      let depth = [worktree.path, worktree.path.resolvingSymlinksInPath()].map(\.pathComponents)
        .filter { root in spellings.contains { $0.starts(with: root) } }
        .map(\.count).max()
      return depth.map { (worktree, $0) }
    }
    return matches.max { $0.1 < $1.1 }?.0
  }

  /// `state` is what the report meant, not what it said: a Done held back for
  /// background workers raises no banner, and the one releasing it does.
  private func notifyIfNeeded(
    _ report: SessionStateReport, as state: SessionState, key: SessionStates.Key,
    worktreeID: Worktree.ID, isSeen: Bool
  ) {
    guard
      NotificationPolicy.shouldNotify(
        state, preference: workspace.notifications, isSeen: isSeen,
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
      body: NotificationPolicy.body(for: state, message: report.message),
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
      // A worktree whose directory has gone is not selected, and activating
      // a tab in it would rewrite what the selected worktree shows.
      guard select(worktree) else { return }
      activate(tab)
    case .worktree(let id):
      if let worktree = workspace.worktree(id) { select(worktree) }
    }
  }

  func noteCommandFinished(in id: TerminalSession.ID, exitCode: Int32?) {
    if let session = workspace.session(id) {
      scheduleStatusRefresh(of: session.worktreeID)
    }
    // An agent typed at the prompt was the foreground command, so the pane is
    // a plain shell again; with the board closed no pid poll would say so.
    setIfChanged(\.reportedAgents[id], nil)
    mutateStates { $0.noteCommandFinished(in: id, exitCode: exitCode, isSeen: hasBeenSeen(id)) }
    updateDockBadge()
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

  public func state(of tab: TerminalTab) -> SessionState? {
    sessionStates.state(ofSessions: tab.sessionIDs)
  }

  public func state(ofWorktree id: Worktree.ID) -> SessionState? {
    state(ofWorktree: id, sessions: worktreeSessions)
  }

  /// The sidebar's form, one grouping serving every row of a render.
  public func state(ofWorktree id: Worktree.ID, sessions: WorktreeSessions) -> SessionState? {
    sessionStates.state(ofWorktree: id, sessions: sessions[id])
  }

  /// One pane's own state, for its sidebar row.
  public func state(ofPane id: TerminalSession.ID) -> SessionState? {
    sessionStates[.session(id)]
  }

  /// The workers out under one pane, for its row's chip. Empty is no chip.
  public func subagents(ofPane id: TerminalSession.ID) -> [Subagent] {
    sessionStates.subagents(.session(id))
  }

  /// The most urgent of the project's worktrees, for its row while collapsed.
  public func state(ofProject id: Project.ID, sessions: WorktreeSessions) -> SessionState? {
    SessionState.mostUrgent(
      workspace.worktrees(of: id).compactMap { state(ofWorktree: $0.id, sessions: sessions) })
  }

  /// One pass over the sessions, taken at the top of a render.
  public var worktreeSessions: WorktreeSessions { WorktreeSessions(workspace.sessions) }

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
    guard setIfChanged(\.reportedAgents, reportedAgents.filter { $0.value.pid != pid }) else {
      return
    }
    updateDockBadge()
  }
}
