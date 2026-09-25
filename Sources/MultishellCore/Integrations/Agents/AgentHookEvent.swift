/// One event an agent's hooks are asked for, and what it says the session
/// is doing.
struct AgentHookEvent: Hashable, Sendable {
  /// What the settings file calls the event.
  let name: String
  /// What the payload calls it, usually the same word. Copilot takes
  /// `notification` in its file and reports `Notification`.
  let reportedName: String
  let state: SessionState
  /// Which occurrences of the event to ask for, where the agent can filter
  /// them and only some of them mean what we are after.
  let matcher: String?
  /// Whether the event means waiting only in a mode that stops for the user;
  /// see Docs/design/agents.md.
  let onlyWhenPrompting: Bool
  /// Which notification types this event does not stand for, where all arrive
  /// on one. A deny list; see Docs/design/agents.md.
  let ignoredNotificationTypes: Set<String>
  /// Whether the event moves the dot and says nothing else, for the second
  /// of two events standing for one thing.
  let silent: Bool
  /// What the event says about the subagent its payload names: its start or
  /// its end. Any other event naming one is a tool call inside it.
  let subagentPhase: SubagentReport.Phase?
  /// Whether the event is a prompt starting a turn, after which nothing of
  /// the last turn is still out.
  let isPrompt: Bool
  /// Where the agent caps this event's hooks below the usual timeout.
  let timeoutSeconds: Int?
  /// Whether this is the agent's session starting, which moves nothing from
  /// a turn already under way.
  let startsSession: Bool

  init(
    _ name: String, _ state: SessionState, reportedName: String? = nil, matcher: String? = nil,
    ignoredNotificationTypes: Set<String> = [], onlyWhenPrompting: Bool = false,
    silent: Bool = false, subagentPhase: SubagentReport.Phase? = nil,
    isPrompt: Bool = false, startsSession: Bool = false, timeoutSeconds: Int? = nil
  ) {
    self.name = name
    self.reportedName = reportedName ?? name
    self.state = state
    self.matcher = matcher
    self.ignoredNotificationTypes = ignoredNotificationTypes
    self.onlyWhenPrompting = onlyWhenPrompting
    self.silent = silent
    self.subagentPhase = subagentPhase
    self.isPrompt = isPrompt
    self.timeoutSeconds = timeoutSeconds
    self.startsSession = startsSession
  }

  /// Whether this is the agent's own prompt starting a turn: one inside a
  /// worker, should an agent ever send one, starts nothing of the agent's.
  func startsTurn(for payload: AgentHookPayload) -> Bool {
    isPrompt && subagentChange(for: payload) == nil
  }

  /// The roster change this event and payload amount to, or nothing for the
  /// main thread's.
  func subagentChange(for payload: AgentHookPayload) -> SubagentReport? {
    let type = payload.agentType
    guard let phase = subagentPhase else {
      // Any other event is a tool call, which is a worker's only where one
      // is named: an agent's own carries no id.
      guard let id = payload.agentID else { return nil }
      return SubagentReport(id: id, type: type, phase: .working)
    }
    // A start or an end moved the roster by one, so one naming nobody takes
    // an unnamed place; read as the agent's own it leaves a worker over.
    let id = payload.agentID ?? SubagentReport.anonymousID
    return SubagentReport(id: id, type: type, phase: phase)
  }
}
