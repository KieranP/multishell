import Foundation

/// A payload turned into the report the helper sends.
extension AgentHookIntegration {
  /// Whether a payload is one of the asked-for events, which the helper asks
  /// before it walks its ancestry for a pid.
  public func asksFor(_ payload: AgentHookPayload) -> Bool {
    event(for: payload) != nil
  }

  /// Which asked-for event a payload is, or nothing where it says nothing
  /// about waiting. The hook exits quietly on nothing.
  func event(for payload: AgentHookPayload) -> AgentHookEvent? {
    guard let event = events.first(where: { $0.reportedName == payload.eventName }) else {
      return nil
    }
    if event.meansWaitingOnlyWhenPrompting, !payload.promptsForPermission { return nil }
    if let type = payload.notificationType, event.ignoredNotificationTypes.contains(type) {
      return nil
    }
    // A subagent's own Stop, which its SubagentStop follows: read as the
    // agent's, it put the pane at Done in the middle of the turn.
    if subagentsAreConversations, event.state.isFinished, payload.isFiledUnderAnotherConversation {
      return nil
    }
    return event
  }

  /// What the helper sends for a payload, or nothing where it says nothing.
  /// `findBackgroundShells` walks the processes, so it is asked only at a Stop.
  public func report(
    for payload: AgentHookPayload, sessionID: TerminalSession.ID?, workingDirectory: String?,
    pid: Int32?,
    findBackgroundShells: (_ marker: String) -> [Int32]? = { _ in nil }
  ) -> SessionStateReport? {
    guard let event = event(for: payload) else { return nil }
    let isStop = event.state == .done
    return SessionStateReport(
      state: event.state,
      sessionID: sessionID,
      workingDirectory: payload.workingDirectory ?? workingDirectory,
      pid: pid,
      message: payload.message,
      agentID: id,
      isSilent: event.isSilent ? true : nil,
      worker: event.workerChange(for: payload)
        .map { withMetadata(pausedOrFailedAtItsOwnStop($0, at: payload), from: payload) },
      launched: launchedTask(in: payload),
      killedTaskID: toolResultsNameBackgroundTasks ? payload.stoppedTaskID : nil,
      startsTurn: event.startsTurn(for: payload) ? true : nil,
      startsSession: event.startsSession ? true : nil,
      backgroundShells: isStop && payload.backgroundTasks == nil
        ? backgroundShellMarker.flatMap(findBackgroundShells) : nil,
      resumesAfterWorkers: isStop && resumes(at: payload) ? true : nil,
      conversationID: subagentsAreConversations ? payload.conversationID : nil,
      workersOut: isStop || event.subagentPhase == .ended
        ? payload.backgroundTasks.map(workers(from:)) : nil,
      turnFollows: isStop && turnFollows(at: payload) ? true : nil,
      asksQuestion: asksQuestion(payload) ? true : nil)
  }

  /// Claude asks its questions through the permission prompt, whose
  /// notification says it needs permission; only the transcript tells them apart.
  private func asksQuestion(_ payload: AgentHookPayload) -> Bool {
    guard transcriptShowsPendingQuestion, payload.notificationType == "permission_prompt",
      let path = payload.transcriptPath
    else { return false }
    return ClaudeTranscript.asksQuestion(atPath: path)
  }

  /// Claude stops a worker at every turn end, pauses included, and lists it
  /// until its run returns, so one its stop leaves out failed; see agents.md.
  private func pausedOrFailedAtItsOwnStop(
    _ worker: WorkerReport, at payload: AgentHookPayload
  ) -> WorkerReport {
    guard worker.phase == .ended, let tasks = payload.backgroundTasks else { return worker }
    if tasks.contains(where: { $0.id == worker.id && wakingTaskTypes.contains($0.type) }) {
      return WorkerReport(id: worker.id, type: worker.type, phase: .working, isPaused: true)
    }
    guard keepsWorkerMetadataBesideTranscript, let path = payload.transcriptPath,
      ClaudeWorkerMetadata.read(ofWorker: worker.id, transcriptPath: path)?.isBackground == true
    else { return worker }
    return WorkerReport(id: worker.id, type: worker.type, phase: .ended, hasFailed: true)
  }

  /// Claude writes the file after a worker's first start, so a start that finds
  /// it is a resume, and the parent arrives with the first tool call.
  private func withMetadata(
    _ worker: WorkerReport, from payload: AgentHookPayload
  ) -> WorkerReport {
    guard keepsWorkerMetadataBesideTranscript, worker.phase != .ended,
      let path = payload.transcriptPath,
      let metadata = ClaudeWorkerMetadata.read(ofWorker: worker.id, transcriptPath: path)
    else { return worker }
    return WorkerReport(
      id: worker.id, type: worker.type, phase: .working, wakesAgent: worker.wakesAgent,
      isBackgroundShell: worker.isBackgroundShell, parentID: metadata.parentID,
      name: metadata.name, description: metadata.description, isPaused: worker.isPaused)
  }

  /// Under the worker whose tool call it was, or the agent's own.
  private func launchedTask(in payload: AgentHookPayload) -> WorkerReport? {
    guard toolResultsNameBackgroundTasks, let task = payload.launchedTask else { return nil }
    return WorkerReport(
      id: task.id, type: task.type, phase: .started,
      isBackgroundShell: task.isShell ? true : nil, parentID: payload.subagentID,
      name: task.name, description: task.description)
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
        environment: ProcessInfo.processInfo.environment, directory: payload.workingDirectory)
    }
  }

  /// A listed shell is named by the agent's id for it; a subagent by its
  /// kind where the list says, and anything else by what the agent calls it.
  private func workers(from tasks: [AgentHookPayload.BackgroundTask]) -> [WorkerReport] {
    tasks.filter { wakingTaskTypes.contains($0.type) }.map { task in
      task.type == "shell"
        ? WorkerReport(id: task.id, phase: .working, isBackgroundShell: true)
        : WorkerReport(id: task.id, type: task.subagentType ?? task.type, phase: .working)
    }
  }
}
