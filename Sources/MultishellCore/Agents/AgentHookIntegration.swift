import Foundation

/// How one agent is asked to say what it is doing, and where that is
/// written.
///
/// Claude Code, Codex, Gemini CLI and Copilot CLI all run a command at each
/// lifecycle event and hand it the same payload, so one hook line and one
/// parser serve all four; they differ in the file, in what they call each
/// event, and in how that file spells one hook. OpenCode runs no such
/// command, and is given a plugin that calls the helper itself.
public struct AgentHookIntegration: Identifiable, Sendable {
  /// How a file spells the hooks, and whether it is the user's or ours.
  public enum Format: Sendable {
    /// `event: [{ "hooks": [{ "type": "command", "command": …, "timeout": N }] }]`
    /// under `hooks`, in a file the user keeps their own settings in: ours
    /// are merged in and taken back out again, and everything else in the
    /// file is left as it was. Gemini counts the timeout in milliseconds,
    /// Claude Code and Codex in seconds.
    case sharedSettings(millisecondTimeout: Bool)
    /// `{ "version": 1, "hooks": { event: [{ "type": "command", … }] } }`.
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
  public let events: [AgentHookEvent]
  public let format: Format
  /// What the agent asks of the user before it will run a hook, when it
  /// asks anything at all. Codex trusts a hook only once told to.
  public let trustNote: String?

  public init(
    id: String, name: String, file: URL, displayPath: String, events: [AgentHookEvent],
    format: Format, trustNote: String? = nil
  ) {
    self.id = id
    self.name = name
    self.file = file
    self.displayPath = displayPath
    self.events = events
    self.format = format
    self.trustNote = trustNote
  }

  /// Whether the file is Multishell's own, rather than one the user keeps
  /// their own settings in.
  public var isOursAlone: Bool { format.isOursAlone }

  public var isPlugin: Bool {
    if case .plugin = format { return true }
    return false
  }

  /// Which of the events asked for one payload is, or nothing where it
  /// says nothing about whether the agent is waiting: an unknown event, one
  /// this does not ask for, or one the mode has made meaningless. The hook
  /// exits quietly on nothing.
  public func event(for payload: AgentHookPayload) -> AgentHookEvent? {
    guard let event = events.first(where: { $0.reported == payload.eventName }) else { return nil }
    if event.onlyWhenPrompting, !payload.promptsForPermission { return nil }
    return event
  }

  /// What one payload says the session is doing.
  public func state(for payload: AgentHookPayload) -> SessionState? {
    event(for: payload)?.state
  }

  // MARK: - What is written

  /// The hooks as the file spells them: the whole file for one of ours, the
  /// object to merge for a file of the user's.
  public func entries(helper: String = AgentHooks.helperReference) -> [String: Any] {
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
    switch format {
    case .sharedSettings(let millisecondTimeout):
      handler["timeout"] =
        millisecondTimeout ? AgentHooks.timeoutSeconds * 1000 : AgentHooks.timeoutSeconds
    case .ownHookFile:
      handler["timeoutSec"] = AgentHooks.timeoutSeconds
      if let matcher = event.matcher { handler["matcher"] = matcher }
    case .plugin:
      break
    }
    return handler
  }
}
