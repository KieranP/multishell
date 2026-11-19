import MultishellCore

extension AppModel {
  /// What a loop over every pane asks which agent is at each prompt.
  var promptAgents: PromptAgents {
    PromptAgents(states: sessionStates, reported: reportedAgents, typed: commandAgentIDs)
  }

  /// Which agent a pane holds: a program holding it, else one that reported while its
  /// process is up, else one typed at its prompt, as most are, else the tab's own.
  func agentIDAtThePrompt(of session: TerminalSession) -> String? {
    promptAgents.agentID(of: session)
  }

  /// Which agent a tab draws the mark of, `nil` for a shell. The last step
  /// is a scan of every session, so a strip asks this once per tab.
  public func agentIDAtThePrompt(of tab: TerminalTab) -> String? {
    promptAgents.agentID(
      of: tab.focusedSessionID,
      orOpenedAs: workspace.session(tab.focusedSessionID)?.agentID,
    )
  }
}
