/// A tab the command line asks for: a shell, an agent, or a command.
public struct NewTabOrder: Codable, Equatable, Sendable {
  /// The worktree's `ControlID`.
  public let worktreeID: String
  public let agentID: String?
  public let task: String?
  /// Run through the login shell, a shell taking over when it quits.
  public let command: [String]?

  public init(worktreeID: String, agentID: String?, task: String?, command: [String]?) {
    self.worktreeID = worktreeID
    self.agentID = agentID
    self.task = task
    self.command = command
  }
}
