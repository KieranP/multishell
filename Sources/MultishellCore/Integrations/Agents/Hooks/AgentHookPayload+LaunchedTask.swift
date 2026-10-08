/// A worker or shell a tool call started in the background, read from the
/// result Claude Code 2.1.292 hands its PostToolUse; see Docs/design/agents.md.
extension AgentHookPayload {
  struct LaunchedTask: Hashable, Sendable {
    var id: String
    var isShell: Bool
    var type: String?
    var name: String?
    var description: String?
  }
}

extension AgentHookPayload.LaunchedTask {
  /// `nil` for a result that started nothing still running: a foreground
  /// worker's result comes once it has ended.
  init?(toolResponse: [String: Any], toolInput: [String: Any]) {
    if let shellID = toolResponse["backgroundTaskId"] as? String {
      self.init(id: shellID, isShell: true)
    } else if toolResponse["status"] as? String == "async_launched",
      let workerID = toolResponse["agentId"] as? String
    {
      self.init(
        id: workerID, isShell: false, type: toolInput["subagent_type"] as? String,
        name: (toolInput["name"] as? String)?.nonEmpty,
        description: ((toolResponse["description"] ?? toolInput["description"]) as? String)?
          .nonEmpty)
    } else {
      return nil
    }
  }
}
