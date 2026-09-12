import Foundation

/// One event an agent's hooks are asked for, and what it says the session
/// is doing.
public struct AgentHookEvent: Hashable, Sendable {
  /// What the settings file calls the event.
  public let name: String
  /// What the payload calls it, usually the same word. Copilot takes
  /// `notification` in its file and reports `Notification`.
  public let reported: String
  public let state: SessionState
  /// Which occurrences of the event to ask for, where the agent can filter
  /// them and only some of them mean what we are after.
  public let matcher: String?
  /// Whether the event means waiting only in a mode that stops for the user;
  /// see docs/design/agents.md.
  public let onlyWhenPrompting: Bool
  /// Which notification types this event does not stand for, where all arrive
  /// on one. A deny list; see docs/design/agents.md.
  public let ignoredNotificationTypes: Set<String>
  /// Whether the event moves the dot and says nothing else, for the second
  /// of two events standing for one thing.
  public let silent: Bool
  /// What the event does to the count of background workers outstanding: `1`
  /// started, `-1` ended, `0` not about them. See docs/design/agents.md.
  public let subagents: Int

  public init(
    _ name: String, _ state: SessionState, reported: String? = nil, matcher: String? = nil,
    ignoredNotificationTypes: Set<String> = [], onlyWhenPrompting: Bool = false,
    silent: Bool = false, subagents: Int = 0
  ) {
    self.name = name
    self.reported = reported ?? name
    self.state = state
    self.matcher = matcher
    self.ignoredNotificationTypes = ignoredNotificationTypes
    self.onlyWhenPrompting = onlyWhenPrompting
    self.silent = silent
    self.subagents = subagents
  }
}
