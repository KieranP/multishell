/// A worktree the command line asks for, as the New Worktree sheet would
/// make it.
public struct NewWorktreeOrder: Codable, Equatable, Sendable {
  public let branch: String
  public let project: ProjectReference
  /// `false` checks out a branch that already exists.
  public let createsBranch: Bool
  /// What a new branch starts from; `nil` is HEAD.
  public let startPoint: String?
  /// The first tab's agent; `nil` with a task is the project's own agent.
  public let agentID: String?
  public let task: String?
  /// `false` leaves the user's view where it is, the first tab starting out of view.
  public let selectsWorktree: Bool

  public init(
    branch: String,
    project: ProjectReference,
    createsBranch: Bool,
    startPoint: String?,
    agentID: String?,
    task: String?,
    selectsWorktree: Bool = true,
  ) {
    self.branch = branch
    self.project = project
    self.createsBranch = createsBranch
    self.startPoint = startPoint
    self.agentID = agentID
    self.task = task
    self.selectsWorktree = selectsWorktree
  }
}
