import Foundation
import MultishellCore

extension AppModel {
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
    let resuming = changed.keysAwaitingResume.subtracting(sessionStates.keysAwaitingResume)
    sessionStates = changed
    for key in moved { withdrawNotification(about: key) }
    for key in resuming { scheduleResumeDeadline(for: key) }
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
  public var workingAgentCount: Int { sessionStates.workingAgentCount }

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
}
