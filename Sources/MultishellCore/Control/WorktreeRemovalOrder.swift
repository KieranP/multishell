/// A worktree removal the command line asks for, as its row's Remove would do
/// it without the dialog.
public struct WorktreeRemovalOrder: Codable, Equatable, Sendable {
  /// The worktree's `ControlID`.
  public let worktreeID: String
  public let deletesBranch: Bool
  /// `git branch -D`: a branch holding commits no other branch has goes too.
  public let forcesBranchDeletion: Bool
  /// Past a working agent, which is otherwise refused.
  public let force: Bool

  public init(worktreeID: String, deletesBranch: Bool, forcesBranchDeletion: Bool, force: Bool) {
    self.worktreeID = worktreeID
    self.deletesBranch = deletesBranch
    self.forcesBranchDeletion = forcesBranchDeletion
    self.force = force
  }
}
