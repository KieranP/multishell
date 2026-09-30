import Foundation

/// A payload turned into the report the helper sends.
extension AgentHookIntegration {
  /// Whether a payload is one of the asked-for events, which the helper asks
  /// before it walks its ancestry for a pid.
  public func handles(_ payload: AgentHookPayload) -> Bool {
    event(for: payload) != nil
  }

  /// Which asked-for event a payload is, or nothing where it says nothing
  /// about waiting. The hook exits quietly on nothing.
  func event(for payload: AgentHookPayload) -> AgentHookEvent? {
    guard let event = events.first(where: { $0.reportedName == payload.eventName }) else {
      return nil
    }
    if event.onlyWhenPrompting, !payload.promptsForPermission { return nil }
    if let type = payload.notificationType, event.ignoredNotificationTypes.contains(type) {
      return nil
    }
    // A subagent's own Stop, which its SubagentStop follows: read as the
    // agent's, it put the pane at Done in the middle of the turn.
    if workersAreConversations, event.state.isFinished, payload.isFiledUnderAnotherConversation {
      return nil
    }
    return event
  }

  /// What the helper sends for a payload, or nothing where it says nothing.
  /// `backgroundShells` walks the processes, so it is asked only at a Stop.
  public func report(
    for payload: AgentHookPayload, sessionID: TerminalSession.ID?, cwd: String?, pid: Int32?,
    backgroundShells: (_ marker: String) -> [Int32]? = { _ in nil }
  ) -> SessionStateReport? {
    guard let event = event(for: payload) else { return nil }
    let isStop = event.state == .done
    return SessionStateReport(
      state: event.state,
      sessionID: sessionID,
      cwd: payload.cwd ?? cwd,
      pid: pid,
      message: payload.message,
      agent: id,
      silent: event.silent ? true : nil,
      subagent: event.subagentChange(for: payload),
      startsTurn: event.startsTurn(for: payload) ? true : nil,
      startsSession: event.startsSession ? true : nil,
      backgroundShells: isStop && payload.backgroundTasks == nil
        ? backgroundShellMarker.flatMap(backgroundShells) : nil,
      resumesAfterWorkers: isStop && resumes(at: payload) ? true : nil,
      conversationID: workersAreConversations ? payload.conversationID : nil,
      workersOut: isStop ? payload.backgroundTasks.map(workers(from:)) : nil,
      turnFollows: isStop && turnFollows(at: payload) ? true : nil)
  }

  private func turnFollows(at payload: AgentHookPayload) -> Bool {
    guard transcriptQueuesNotices, let path = payload.transcriptPath else { return false }
    return ClaudeTranscript.turnFollows(atPath: path)
  }

  private func resumes(at payload: AgentHookPayload) -> Bool {
    switch resumption {
    case .never: false
    case .always: true
    case .whenGeminiSettingsSay:
      GeminiSettings.wakesForBackgroundShells(
        environment: ProcessInfo.processInfo.environment, workspace: payload.cwd)
    }
  }

  /// A listed shell is named by the agent's id for it; a subagent by its
  /// kind where the list says, and anything else by what the agent calls it.
  private func workers(from tasks: [AgentHookPayload.BackgroundTask]) -> [SubagentReport] {
    tasks.filter { wakingTaskTypes.contains($0.type) }.map { task in
      task.type == "shell"
        ? SubagentReport(id: task.id, phase: .working, isBackgroundShell: true)
        : SubagentReport(id: task.id, type: task.subagentType ?? task.type, phase: .working)
    }
  }
}
