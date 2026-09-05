import Foundation

/// The JSON Claude Code writes to a hook's stdin, reduced to what a state
/// report needs.
public struct ClaudeHookPayload: Hashable, Sendable {
  public var eventName: String
  public var cwd: String?
  public var message: String?

  public init(eventName: String, cwd: String? = nil, message: String? = nil) {
    self.eventName = eventName
    self.cwd = cwd
    self.message = message
  }

  public init?(json data: Data) {
    guard
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let eventName = object["hook_event_name"] as? String
    else { return nil }
    self.eventName = eventName
    self.cwd = object["cwd"] as? String
    self.message = object["message"] as? String
  }

  /// Which state each hook event stands for. Unknown events, and the ones
  /// that say nothing about whether the agent is waiting (`SubagentStop`,
  /// `PreCompact`), map to nothing and the hook exits quietly.
  public static func state(forEvent name: String) -> SessionState? {
    switch name {
    case "UserPromptSubmit", "PreToolUse", "PostToolUse": .running
    case "Notification": .attention
    case "Stop": .done
    case "StopFailure": .error
    case "SessionStart", "SessionEnd": .idle
    default: nil
    }
  }

  public var state: SessionState? {
    Self.state(forEvent: eventName)
  }

  /// Only the events that map to a state; the rest are not worth a process.
  public static let hookedEvents = [
    "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification", "Stop",
    "StopFailure", "SessionEnd",
  ]
}
