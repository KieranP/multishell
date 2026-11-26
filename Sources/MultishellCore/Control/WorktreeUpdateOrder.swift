/// Merge from Base or Rebase onto Base as the command line asks for it, its
/// menu item done without the question the click would ask.
public struct WorktreeUpdateOrder: Codable, Equatable, Sendable {
  /// The worktree's `ControlID`.
  public let worktreeID: String
  public let method: UpdateMethod
  /// Past a working agent, which is otherwise refused.
  public let force: Bool
  /// A rebase of a branch the remote holds, which its next push must force.
  public let allowsRewritingPushedBranch: Bool

  public init(
    worktreeID: String,
    method: UpdateMethod,
    force: Bool,
    allowsRewritingPushedBranch: Bool,
  ) {
    self.worktreeID = worktreeID
    self.method = method
    self.force = force
    self.allowsRewritingPushedBranch = allowsRewritingPushedBranch
  }
}
