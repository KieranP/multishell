/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  /// How to resume the last conversation when a saved agent tab comes back.
  /// `nil` means the tab returns as a plain shell.
  public let resumeArguments: [String]?
  public let taskArgument: AgentTaskArgument
  /// How this agent is told about a file: `@` for one that reads mentions,
  /// `nil` for a plain path. Only set where the prompt is known to resolve.
  public let fileMentionPrefix: String?
  /// The mark drawn wherever this agent is at a prompt, in the theme's
  /// `ui.agent_marks` colour for its id.
  public let mark: AgentMark
  /// Auto Rename's run: one prompt, then exit.
  public let oneShot: AgentOneShot

  init(
    id: String,
    name: String,
    executable: String,
    taskArgument: AgentTaskArgument,
    mark: AgentMark,
    oneShot: AgentOneShot,
    resumeArguments: [String]? = nil,
    fileMentionPrefix: String? = nil,
  ) {
    self.id = id
    self.name = name
    self.executable = executable
    self.resumeArguments = resumeArguments
    self.taskArgument = taskArgument
    self.fileMentionPrefix = fileMentionPrefix
    self.mark = mark
    self.oneShot = oneShot
  }
}
