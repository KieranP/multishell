import Foundation

/// How one agent is asked to say what it is doing, and where that is
/// written; see Docs/design/agents.md.
public struct AgentHookIntegration: Identifiable, Sendable {
  /// How a file spells the hooks, and whether it is the user's or ours.
  enum Format: Sendable {
    /// `hooks` in a file the user keeps their own settings in, ours merged
    /// in and back out. Gemini counts the timeout in milliseconds.
    case sharedSettings(millisecondTimeout: Bool)
    /// Copilot reads every JSON file in its hooks directory, so ours is a
    /// file of its own: written whole, deleted to remove it.
    case ownHookFile
    /// A JavaScript plugin, OpenCode having no hooks in its settings at
    /// all. A file of ours alone, like the one above.
    case plugin

    /// Whether the file holds nothing but what Multishell wrote.
    var isOursAlone: Bool {
      if case .sharedSettings = self { return false }
      return true
    }
  }

  /// The agent's catalogue id, which the hook line carries so a report says
  /// who is at the pane's prompt.
  public let id: String
  public let name: String
  public let file: URL
  /// The file as the settings window names it, `~` and all.
  public let displayPath: String
  let events: [AgentHookEvent]
  let format: Format
  /// What the agent asks of the user before it will run a hook, when it
  /// asks anything at all. Codex trusts a hook only once told to.
  public let trustNote: String?
  /// What the command line of a shell the agent runs a tool in holds, so its
  /// Stop can name those still running; see Docs/design/agents.md.
  public let backgroundShellMarker: String?
  /// Whether the agent takes another turn when the work it left out at its
  /// Stop ends, which then pays the Done; see Docs/design/agents.md.
  public let resumesAfterWorkers: Bool
  /// Whether a subagent is a conversation of its own, firing its own prompt
  /// and Stop, which only its conversation id tells apart; see agents.md.
  let workersAreConversations: Bool

  init(
    id: String, name: String, file: URL, displayPath: String, events: [AgentHookEvent],
    format: Format, trustNote: String? = nil, backgroundShellMarker: String? = nil,
    resumesAfterWorkers: Bool = false, workersAreConversations: Bool = false
  ) {
    self.id = id
    self.name = name
    self.file = file
    self.displayPath = displayPath
    self.events = events
    self.format = format
    self.trustNote = trustNote
    self.backgroundShellMarker = backgroundShellMarker
    self.resumesAfterWorkers = resumesAfterWorkers
    self.workersAreConversations = workersAreConversations
  }

  /// Whether the file is Multishell's own, rather than one the user keeps
  /// their own settings in.
  public var isOursAlone: Bool { format.isOursAlone }

  public var isPlugin: Bool {
    if case .plugin = format { return true }
    return false
  }

  /// Which asked-for event a payload is, or nothing where it says nothing
  /// about waiting. The hook exits quietly on nothing.
  public func event(for payload: AgentHookPayload) -> AgentHookEvent? {
    guard let event = events.first(where: { $0.reported == payload.eventName }) else { return nil }
    if event.onlyWhenPrompting, !payload.promptsForPermission { return nil }
    if let type = payload.notificationType, event.ignoredNotificationTypes.contains(type) {
      return nil
    }
    // A subagent's own Stop, which its SubagentStop follows: read as the
    // agent's, it put the pane at Done in the middle of the turn.
    if workersAreConversations, event.state.isFinished, payload.isFiledUnderAnotherConversation {
      return nil
    }
    return event
  }

  /// What the helper sends for a payload, or nothing where it says nothing.
  /// `backgroundShells` walks the processes, so it is asked only at a Stop.
  public func report(
    for payload: AgentHookPayload, session: TerminalSession.ID?, cwd: String?, pid: Int32?,
    backgroundShells: (_ marker: String) -> [Int32]? = { _ in nil }
  ) -> SessionStateReport? {
    guard let event = event(for: payload) else { return nil }
    let isStop = event.state == .done
    return SessionStateReport(
      state: event.state,
      sessionID: session,
      cwd: payload.cwd ?? cwd,
      pid: pid,
      message: payload.message,
      agent: id,
      silent: event.silent ? true : nil,
      subagent: event.subagentReport(for: payload),
      startsTurn: event.startsTurn(for: payload) ? true : nil,
      startsSession: event.startsSession ? true : nil,
      backgroundShells: isStop ? backgroundShellMarker.flatMap(backgroundShells) : nil,
      resumesAfterWorkers: isStop && resumesAfterWorkers ? true : nil,
      conversationID: workersAreConversations ? payload.conversationID : nil)
  }

  /// The hooks as the file spells them: the whole file for one of ours, the
  /// object to merge for a file of the user's.
  func entries(helper: String = AgentHooks.helperReference) -> [String: Any] {
    switch format {
    case .sharedSettings:
      var hooks: [String: Any] = [:]
      for event in events { hooks[event.name] = [group(event, helper: helper)] }
      return ["hooks": hooks]
    case .ownHookFile:
      var hooks: [String: Any] = [:]
      for event in events { hooks[event.name] = [handler(event, helper: helper)] }
      return ["version": 1, "hooks": hooks]
    case .plugin:
      return [:]
    }
  }

  /// What the settings window shows and the clipboard gets.
  public func snippet(helper: String = AgentHooks.helperReference) -> String {
    switch format {
    case .plugin: OpenCodePlugin.source(helper: helper)
    case .sharedSettings, .ownHookFile: HookSettingsFile.render(entries(helper: helper))
    }
  }

  /// A matcher goes on the group, where the file has groups, and on the
  /// hook itself where it does not.
  func group(_ event: AgentHookEvent, helper: String) -> [String: Any] {
    var group: [String: Any] = ["hooks": [handler(event, helper: helper)]]
    if let matcher = event.matcher { group["matcher"] = matcher }
    return group
  }

  private func handler(_ event: AgentHookEvent, helper: String) -> [String: Any] {
    var handler: [String: Any] = [
      "type": "command", "command": AgentHooks.command(agent: id, helper: helper),
    ]
    let timeout = event.timeoutSeconds ?? AgentHooks.timeoutSeconds
    switch format {
    case .sharedSettings(let millisecondTimeout):
      handler["timeout"] = millisecondTimeout ? timeout * 1000 : timeout
    case .ownHookFile:
      handler["timeoutSec"] = timeout
      if let matcher = event.matcher { handler["matcher"] = matcher }
    case .plugin:
      break
    }
    return handler
  }
}
