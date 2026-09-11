import Foundation

/// One event an agent's hooks are asked for, and what it says the session
/// is doing.
public struct AgentHookEvent: Hashable, Sendable {
  /// What the settings file calls the event.
  public let name: String
  /// What the payload calls it, which is usually the same word. Copilot
  /// takes `notification` in its file and reports `Notification` in the
  /// payload, and a hook that read either name from the other would map
  /// nothing.
  public let reported: String
  public let state: SessionState
  /// Which occurrences of the event to ask for, where the agent can filter
  /// them and only some of them mean what we are after.
  public let matcher: String?
  /// Whether the event means waiting only when the agent is in a mode that
  /// stops for the user. Codex asks its hook before deciding whether a call
  /// needs anyone at all, so under `--full-auto` the event fires for work
  /// nobody is waiting on.
  public let onlyWhenPrompting: Bool
  /// Which of the event's notification types mean its state, where every
  /// type arrives on one event and the payload names which. Empty takes
  /// them all, as does a payload naming no type: an agent from before the
  /// field keeps the dot it had.
  public let notificationTypes: Set<String>
  /// Whether the event moves the dot and says nothing else. For the second
  /// of two events that stand for one thing: Claude reports a permission
  /// prompt twice, and one banner is enough.
  public let silent: Bool

  public init(
    _ name: String, _ state: SessionState, reported: String? = nil, matcher: String? = nil,
    notificationTypes: Set<String> = [], onlyWhenPrompting: Bool = false, silent: Bool = false
  ) {
    self.name = name
    self.reported = reported ?? name
    self.state = state
    self.matcher = matcher
    self.notificationTypes = notificationTypes
    self.onlyWhenPrompting = onlyWhenPrompting
    self.silent = silent
  }
}
