import MultishellCore

extension AppModel {
  /// Asked before a tab opens, which would otherwise come up a plain shell
  /// that a script reads as the agent's; the launch's own checks, ahead of it.
  private func refusalToStart(agent id: String) -> ControlRefusal? {
    guard id != AgentCatalogue.customID else { return nil }
    guard AgentCatalogue.agent(id) != nil else { return .noAgent(id: id) }
    // Until the login shell has answered, the launch lets the shell say so.
    guard loginEnvironment == nil || agentDetection.isInstalled(id) else {
      return .agentNotInstalled(id: id)
    }
    return nil
  }

  /// `nil` where neither an agent nor a task is asked for; else the agent
  /// named or the place's own, refused where there is neither or it cannot start.
  func agentToStart(
    _ named: String?,
    task: String?,
    otherwise fallback: String?,
  ) -> Result<String?, ControlRefusal> {
    guard named != nil || task != nil else { return .success(nil) }
    guard let id = named ?? fallback else { return .failure(.noAgentChosen) }
    if let refusal = refusalToStart(agent: id) { return .failure(refusal) }
    return .success(id)
  }

  /// Refused over a working agent unless forced, rather than asked: a dialog
  /// nobody at the command line can see would stand until someone clicks it.
  func refusesOverWorkingAgent(in sessions: [TerminalSession.ID], force: Bool) -> Bool {
    !force && sessions.contains(where: isAgentWorking(in:))
  }
}
