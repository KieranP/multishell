import MultishellCore

extension AppModel {
  /// Which agent a pane holds: the one that reported while its process is up,
  /// else the tab's own. Most panes get theirs typed at a shell prompt.
  func agentAtThePrompt(of session: TerminalSession) -> String? {
    agentAtThePrompt(session.id, orOpenedAs: session.agentID)
  }

  /// Which agent a tab draws the mark of, `nil` for a shell. The last step
  /// is a scan of every session, so a strip asks this once per tab.
  public func agentAtThePrompt(of tab: TerminalTab) -> String? {
    agentAtThePrompt(
      tab.focusedSessionID, orOpenedAs: workspace.session(tab.focusedSessionID)?.agentID)
  }

  private func agentAtThePrompt(
    _ id: TerminalSession.ID, orOpenedAs openedAs: @autoclosure () -> String?
  ) -> String? {
    if let reported = reportedAgents[id], reported.isAtThePrompt { return reported.agentID }
    return commandAgentIDs[id] ?? openedAs()
  }

  /// Whether an agent is at this pane's prompt, the report winning over the
  /// tab's own id.
  func isAgentPane(_ session: TerminalSession) -> Bool {
    agentAtThePrompt(of: session) != nil
  }
}
