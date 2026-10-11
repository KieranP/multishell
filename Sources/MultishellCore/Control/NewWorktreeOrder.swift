/// A worktree the command line asks for, as the New Worktree sheet would
/// make it.
public struct NewWorktreeOrder: Codable, Equatable, Sendable {
  public let branch: String
  /// The project's `ControlID`.
  public let projectID: String
  /// `false` checks out a branch that already exists.
  public let createsBranch: Bool
  /// What a new branch starts from; `nil` is HEAD.
  public let startPoint: String?
  /// The first tab's agent; `nil` with a task is the project's own agent.
  public let agentID: String?
  public let task: String?

  public init(
    branch: String,
    projectID: String,
    createsBranch: Bool,
    startPoint: String?,
    agentID: String?,
    task: String?,
  ) {
    self.branch = branch
    self.projectID = projectID
    self.createsBranch = createsBranch
    self.startPoint = startPoint
    self.agentID = agentID
    self.task = task
  }
}
