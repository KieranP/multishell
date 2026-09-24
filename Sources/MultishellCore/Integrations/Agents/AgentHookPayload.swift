import Foundation

/// The JSON an agent writes to a hook command's stdin, reduced to the fields
/// this reads; see Docs/design/agents.md.
public struct AgentHookPayload: Hashable, Sendable {
  var eventName: String
  public var cwd: String?
  public var message: String?
  /// The approval mode the agent is in, where it says: `default`,
  /// `dontAsk` and the rest. Claude Code and Codex are the ones that say.
  var permissionMode: String?
  /// Which kind of notification this is, where the agent says. Claude Code
  /// is the one that does.
  var notificationType: String?
  /// The subagent the event fired inside, or the one a start or stop names.
  /// Claude Code and Codex set it on every event of a subagent's.
  public var agentID: String?
  var agentType: String?
  /// The agent's own id for the conversation. Copilot runs a subagent as a
  /// conversation of its own, whose id its SubagentStop names as `agent_id`.
  var conversationID: String?
  var transcriptPath: String?

  public init(
    eventName: String, cwd: String? = nil, message: String? = nil, permissionMode: String? = nil,
    notificationType: String? = nil, agentID: String? = nil, agentType: String? = nil,
    conversationID: String? = nil, transcriptPath: String? = nil
  ) {
    self.eventName = eventName
    self.cwd = cwd
    self.message = message
    self.permissionMode = permissionMode
    self.notificationType = notificationType
    self.agentID = agentID
    self.agentType = agentType
    self.conversationID = conversationID
    self.transcriptPath = transcriptPath
  }

  public init?(json data: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let eventName = object["hook_event_name"] as? String
    else { return nil }
    self.eventName = eventName
    self.cwd = object["cwd"] as? String
    self.message = object["message"] as? String
    self.permissionMode = object["permission_mode"] as? String
    self.notificationType = object["notification_type"] as? String
    self.agentID = object["agent_id"] as? String
    self.agentType = object["agent_type"] as? String
    self.conversationID = object["session_id"] as? String
    self.transcriptPath = object["transcript_path"] as? String
  }

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
