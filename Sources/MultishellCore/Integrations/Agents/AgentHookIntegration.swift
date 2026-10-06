import Foundation

/// How one agent is asked to say what it is doing, and where that is
/// written; see Docs/design/agents.md.
public struct AgentHookIntegration: Identifiable, Sendable {
  /// How a file spells the hooks, and whether it is the user's or ours.
  enum Format: Sendable {
    /// `hooks` in a file the user keeps their own settings in, ours merged
    /// in and back out. Gemini counts the timeout in milliseconds.
    case userSettingsFile(timeoutIsInMilliseconds: Bool)
    /// Copilot reads every JSON file in its hooks directory, so ours is a
    /// file of its own: written whole, deleted to remove it.
    case ownHookFile
    /// A JavaScript plugin, OpenCode having no hooks in its settings at
    /// all. A file of ours alone, like the one above.
    case plugin

    /// Whether the file holds nothing but what Multishell wrote.
    var isOursAlone: Bool {
      if case .userSettingsFile = self { return false }
      return true
    }
  }

  enum Resumption: Sendable {
    case never
    case always
    /// Only where the user's settings turn it on, read at each Done.
    case whenGeminiSettingsSay
  }

  /// The agent's catalogue id, which the hook line carries so a report says
  /// who is at the pane's prompt.
  public let id: String
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
  let backgroundShellMarker: String?
  /// Whether the agent takes another turn when the work it left out at its
  /// Stop ends, which then pays the Done; see Docs/design/agents.md.
  let resumption: Resumption
  /// Whether a subagent is a conversation of its own, firing its own prompt
  /// and Stop, which only its conversation id tells apart; see agents.md.
  let subagentsAreConversations: Bool
  /// The kinds of listed work whose end reaches the model and wakes it. One
  /// counted that never wakes it holds the pane Working for good; see agents.md.
  let wakingTaskTypes: Set<String>
  /// Whether the agent's transcript shows a finished task's notice still
  /// queued at a Stop, which starts a turn straight after; see agents.md.
  let transcriptQueuesNotices: Bool
  /// Whether the agent's questions reach a hook as permission prompts, which
  /// only its transcript tells apart; see agents.md.
  let transcriptShowsPendingQuestion: Bool

  init(
    id: String, file: URL, displayPath: String, events: [AgentHookEvent],
    format: Format, trustNote: String? = nil, backgroundShellMarker: String? = nil,
    resumption: Resumption = .never, subagentsAreConversations: Bool = false,
    wakingTaskTypes: Set<String> = [], transcriptQueuesNotices: Bool = false,
    transcriptShowsPendingQuestion: Bool = false
  ) {
    self.id = id
    self.file = file
    self.displayPath = displayPath
    self.events = events
    self.format = format
    self.trustNote = trustNote
    self.backgroundShellMarker = backgroundShellMarker
    self.resumption = resumption
    self.subagentsAreConversations = subagentsAreConversations
    self.wakingTaskTypes = wakingTaskTypes
    self.transcriptQueuesNotices = transcriptQueuesNotices
    self.transcriptShowsPendingQuestion = transcriptShowsPendingQuestion
  }

  public var name: String { AgentCatalogue.agent(id)?.name ?? id }

  public var isOursAlone: Bool { format.isOursAlone }

  public var isPlugin: Bool {
    if case .plugin = format { return true }
    return false
  }
}
