/// A coding agent the app knows how to start.
public struct AgentDescriptor: Identifiable, Hashable, Sendable {
  public let id: String
  public let name: String
  /// Looked up on the login shell's PATH.
  public let executable: String
  public let launchArguments: [String]
  /// How to resume the last conversation when a saved agent tab comes back.
  /// `nil` means the tab returns as a plain shell.
  public let resumeArguments: [String]?
  /// How this agent is told about a file: `@` for one that reads mentions,
  /// `nil` for a plain path. Only set where the prompt is known to resolve.
  public let fileMentionPrefix: String?
  /// The mark drawn wherever this agent is at a prompt.
  public let mark: AgentMark
  /// The hex `mark` is drawn at. `nil` draws it in the theme's own text
  /// colour, which is what a project mark that is black or white wants.
  let markTint: String?

  public init(
    id: String, name: String, executable: String, launchArguments: [String] = [],
    resumeArguments: [String]? = nil, fileMentionPrefix: String? = nil,
    mark: AgentMark, markTint: String? = nil
  ) {
    self.id = id
    self.name = name
    self.executable = executable
    self.launchArguments = launchArguments
    self.resumeArguments = resumeArguments
    self.fileMentionPrefix = fileMentionPrefix
    self.mark = mark
    self.markTint = markTint
  }
}
