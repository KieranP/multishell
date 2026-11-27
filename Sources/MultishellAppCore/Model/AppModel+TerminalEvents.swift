import MultishellCore

extension AppModel {
  /// Activity in the pane with the keyboard is being watched; anywhere else,
  /// a split's other pane included, it is remembered until that pane is focused.
  func noteActivity(in id: TerminalSession.ID) {
    mutateStates { $0.noteActivity(in: id, isSeen: isSeen(id)) }
  }

  /// A retitle is activity for the pane's dot. An action's tab keeps its
  /// action's name over whatever its shell reports.
  func noteTitle(_ title: String, of id: TerminalSession.ID) {
    if workspace.session(id)?.actionName == nil { setIfChanged(\.sessionTitles[id], title) }
    noteActivity(in: id)
  }

  func noteCommandFinished(in id: TerminalSession.ID, exitCode: Int32?) {
    // An agent typed at the prompt was the foreground command, so the pane is
    // a plain shell again; with the board closed no pid poll would say so.
    forgetReportedAgent(in: id)
    // The first end in an action's tab is the action's own, its wrapper's mark.
    setIfChanged(\.actionRunStarts, actionRunStarts.filter { $0.key != id })
    mutateStates { $0.noteCommandFinished(in: id, exitCode: exitCode, isSeen: isSeen(id)) }
    updateDockBadge()
    updatePIDWatch()
  }

  /// A session opened or closed: what is kept per session goes with it.
  func noteLiveSessionsChanged() {
    let live = reconciler.liveSessionIDs
    setIfChanged(\.liveSessionIDs, live)
    setIfChanged(\.sessionTitles, sessionTitles.filter { live.contains($0.key) })
    setIfChanged(\.reportedAgents, reportedAgents.filter { live.contains($0.key) })
    reportedAgentDirectories = reportedAgentDirectories.filter { live.contains($0.key) }
    setIfChanged(\.commandAgentIDs, commandAgentIDs.filter { live.contains($0.key) })
    pruneStates()
    pruneFind()
    // A shell exiting can bring another pane the keyboard; it is being
    // looked at now, whatever happened in it before.
    markInViewSeen()
  }
}
