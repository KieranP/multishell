import Foundation

/// The JSON an agent writes to a hook command's stdin, reduced to what a
/// state report needs.
///
/// Claude Code, Codex, Gemini CLI and Copilot CLI all spell these three the
/// same way, so one parser serves them: the event that fired, the directory
/// the agent is working in, and the text of a notification. Everything else
/// in the payload is the agent's own business. Which state an event stands
/// for is the agent's, and lives in its `AgentHookIntegration`.
public struct AgentHookPayload: Hashable, Sendable {
  public var eventName: String
  public var cwd: String?
  public var message: String?
  /// The approval mode the agent is in, where it says: `default`,
  /// `dontAsk` and the rest. Codex is the one that says.
  public var permissionMode: String?

  public init(
    eventName: String, cwd: String? = nil, message: String? = nil, permissionMode: String? = nil
  ) {
    self.eventName = eventName
    self.cwd = cwd
    self.message = message
    self.permissionMode = permissionMode
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
  }

  /// Whether the mode the payload names is one that stops for the user. A
  /// mode this build has not heard of is taken to prompt: a dot that goes
  /// amber when it need not costs less than one that never does.
  public var promptsForPermission: Bool {
    switch permissionMode {
    case "dontAsk", "bypassPermissions": false
    default: true
    }
  }
}
