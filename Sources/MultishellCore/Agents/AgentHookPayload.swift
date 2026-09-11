import Foundation

/// The JSON an agent writes to a hook command's stdin, reduced to the three
/// fields all four spell alike; see docs/design/agents.md.
public struct AgentHookPayload: Hashable, Sendable {
  public var eventName: String
  public var cwd: String?
  public var message: String?
  /// The approval mode the agent is in, where it says: `default`,
  /// `dontAsk` and the rest. Claude Code and Codex are the ones that say.
  public var permissionMode: String?
  /// Which kind of notification this is, where the agent says. Claude Code
  /// is the one that does.
  public var notificationType: String?

  public init(
    eventName: String, cwd: String? = nil, message: String? = nil, permissionMode: String? = nil,
    notificationType: String? = nil
  ) {
    self.eventName = eventName
    self.cwd = cwd
    self.message = message
    self.permissionMode = permissionMode
    self.notificationType = notificationType
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
  }

  /// Whether the payload's mode stops for the user. An unknown one is taken
  /// to prompt: a needless blue dot costs less than a missing one.
  public var promptsForPermission: Bool {
    switch permissionMode {
    // Claude's `auto` has a classifier answer the request, so it is one
    // more mode where the agent asks the hook and nobody is waiting.
    case "dontAsk", "bypassPermissions", "auto": false
    default: true
    }
  }
}
