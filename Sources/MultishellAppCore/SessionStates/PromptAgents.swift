import MultishellCore

/// What says which agent is at each pane's prompt, read off the model once:
/// a loop over every pane reading the model per pane cost a millisecond at 200.
struct PromptAgents {
  let states: SessionStates
  let reported: [TerminalSession.ID: ReportedAgent]
  let typed: [TerminalSession.ID: String]

  /// A program holding the pane, else an agent that reported while its process
  /// is up, else the one typed at the prompt, else the tab's own.
  func agentID(
    of id: TerminalSession.ID,
    orOpenedAs openedAs: @autoclosure () -> String?,
  )
    -> String?
  {
    if let agent = states.programAgent(.session(id)) { return agent.id }
    if let reported = reported[id], reported.isAtThePrompt { return reported.agentID }
    return typed[id] ?? openedAs()
  }

  func agentID(of session: TerminalSession) -> String? {
    agentID(of: session.id, orOpenedAs: session.agentID)
  }
}
