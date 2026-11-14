/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public static let conversationPlaceholder = "{conversation}"

  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  /// How to resume the last conversation when a saved agent tab comes back.
  /// `nil` means the tab returns as a plain shell.
  public let resumeArguments: [String]?
  /// How to resume one conversation by its id, `conversationPlaceholder` standing
  /// for it; `nil` where no hook reports one, and `resumeArguments` is used.
  public let conversationResumeArguments: [String]?
  public let taskArgument: AgentTaskArgument
  /// How this agent is told about a file: `@` for one that reads mentions,
  /// `nil` for a plain path. Only set where the prompt is known to resolve.
  public let fileMentionPrefix: String?
  /// The mark drawn wherever this agent is at a prompt, in the theme's
  /// `ui.agent_marks` colour for its id.
  let mark: AgentMark
  /// Auto Rename's run: one prompt, then exit.
  public let oneShot: AgentOneShot
  /// The `app` its OSC 7501 reports name it by, where it sends them.
  let programStatusApp: String?

  init(
    id: String,
    name: String,
    executable: String,
    taskArgument: AgentTaskArgument,
    mark: AgentMark,
    oneShot: AgentOneShot,
    resumeArguments: [String]? = nil,
    conversationResumeArguments: [String]? = nil,
    fileMentionPrefix: String? = nil,
    programStatusApp: String? = nil,
  ) {
    self.id = id
    self.name = name
    self.executable = executable
    self.resumeArguments = resumeArguments
    self.conversationResumeArguments = conversationResumeArguments
    self.taskArgument = taskArgument
    self.fileMentionPrefix = fileMentionPrefix
    self.mark = mark
    self.oneShot = oneShot
    self.programStatusApp = programStatusApp
  }
}
