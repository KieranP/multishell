import Foundation

/// The JSON an agent writes to a hook command's stdin, reduced to the fields
/// this reads; see Docs/design/agents.md.
public struct AgentHookPayload: Hashable, Sendable {
  struct BackgroundTask: Hashable, Sendable {
    var id: String
    /// `subagent`, `shell`, `monitor` and so on, the agent's own label.
    var taskType: String
    var subagentType: String?
  }

  var eventName: String
  var workingDirectory: String?
  var message: String?
  /// The approval mode the agent is in, where it says: `default`,
  /// `dontAsk` and the rest. Claude Code and Codex are the ones that say.
  var permissionMode: String?
  /// Which kind of notification this is, where the agent says. Claude Code
  /// is the one that does.
  var notificationType: String?
  /// The subagent the event fired inside, or the one a start or stop names.
  /// Claude Code and Codex set it on every event of a subagent's.
  var subagentID: String?
  var subagentType: String?
  /// The agent's own id for the conversation. Copilot runs a subagent as a
  /// conversation of its own, whose id its SubagentStop names as `agent_id`.
  var conversationID: String?
  var transcriptPath: String?
  /// What Claude's Stop says is still in flight, `nil` from an agent or a
  /// version that does not say; see Docs/design/agents.md.
  var backgroundTasks: [BackgroundTask]?
  /// What a tool call's result says it started in the background, where the
  /// result is Claude's; see Docs/design/agents.md.
  var launchedTask: LaunchedTask?
  /// The task a TaskStop result says it stopped, which Claude ends with all
  /// it launched; see Docs/design/agents.md.
  var killedTaskID: String?

  /// Whether the transcript is another conversation's: Copilot files a
  /// subagent's under its parent's id; see Docs/design/agents.md.
  var isFiledUnderAnotherConversation: Bool {
    guard let conversationID, !conversationID.isEmpty, let transcriptPath else { return false }
    return !transcriptPath.contains(conversationID)
  }

  /// Whether the payload's mode stops for the user. An unknown one is taken
  /// to prompt: a needless blue dot costs less than a missing one.
  var promptsForPermission: Bool {
    switch permissionMode {
    // Claude's `auto` has a classifier answer the request, so it is one
    // more mode where the agent asks the hook and nobody is waiting.
    case "dontAsk", "bypassPermissions", "auto": false
    default: true
    }
  }
}

// A memberwise init stays synthesized for the tests to build one with.
// swiftlint:disable:next no_grouping_extension
extension AgentHookPayload {
  public init?(json data: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let eventName = object["hook_event_name"] as? String
    else { return nil }
    self.eventName = eventName
    self.workingDirectory = object["cwd"] as? String
    self.message = object["message"] as? String
    self.permissionMode = object["permission_mode"] as? String
    self.notificationType = object["notification_type"] as? String
    self.subagentID = object["agent_id"] as? String
    self.subagentType = object["agent_type"] as? String
    self.conversationID = object["session_id"] as? String
    self.transcriptPath = object["transcript_path"] as? String
    self.backgroundTasks = (object["background_tasks"] as? [Any]).map { tasks in
      tasks.compactMap { task in
        guard let task = task as? [String: Any], let id = task["id"] as? String,
          let taskType = task["type"] as? String
        else { return nil }
        return BackgroundTask(
          id: id,
          taskType: taskType,
          subagentType: task["agent_type"] as? String,
        )
      }
    }
    self.launchedTask = (object["tool_response"] as? [String: Any]).flatMap { response in
      LaunchedTask(
        toolResponse: response,
        toolInput: object["tool_input"] as? [String: Any] ?? [:],
      )
    }
    if object["tool_name"] as? String == "TaskStop" {
      self.killedTaskID = (object["tool_response"] as? [String: Any])?["task_id"] as? String
    }
  }
}
