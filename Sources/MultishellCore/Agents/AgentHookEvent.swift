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
  /// What the event says about the subagent its payload names: its start or
  /// its end. Any other event naming one is a tool call inside it.
  public let subagent: SubagentReport.Phase?
  /// Whether the event is a prompt starting a turn, after which nothing of
  /// the last turn is still out.
  public let startsTurn: Bool

  public init(
    _ name: String, _ state: SessionState, reported: String? = nil, matcher: String? = nil,
    ignoredNotificationTypes: Set<String> = [], onlyWhenPrompting: Bool = false,
    silent: Bool = false, subagent: SubagentReport.Phase? = nil, startsTurn: Bool = false
  ) {
    self.name = name
    self.reported = reported ?? name
    self.state = state
    self.matcher = matcher
    self.ignoredNotificationTypes = ignoredNotificationTypes
    self.onlyWhenPrompting = onlyWhenPrompting
    self.silent = silent
    self.subagent = subagent
    self.startsTurn = startsTurn
  }

  /// Whether this is the agent's own prompt starting a turn: one inside a
  /// worker, should an agent ever send one, starts nothing of the agent's.
  public func startsTurn(for payload: AgentHookPayload) -> Bool {
    startsTurn && subagentReport(for: payload) == nil
  }

  /// The roster change this event and payload amount to, or nothing for the
  /// main thread's. Copilot names a worker without an id; see agents.md.
  public func subagentReport(for payload: AgentHookPayload) -> SubagentReport? {
    let type = payload.agentType ?? payload.agentName
    guard let phase = subagent else {
      // Any other event is a tool call, which is a worker's only where one
      // is named: an agent's own carries no id.
      guard let id = payload.agentID else { return nil }
      return SubagentReport(id: id, type: type, phase: .working)
    }
    // A start or an end moved the roster by one whatever its payload said, so
    // one that names nobody takes an unnamed place rather than reading as the
    // agent's own report, which would leave the roster a worker over.
    let id = payload.agentID ?? payload.agentName ?? SubagentReport.anonymousID
    return SubagentReport(id: id, type: type, phase: phase)
  }
}
