import MultishellCore

extension AppModel {
  /// By the id `projects list` prints; see `ControlID`.
  func project(withControlID id: String) -> Project? {
    workspace.projects.first { ControlID.project($0.id) == id }
  }

  /// By the id `worktrees list` prints.
  func worktree(withControlID id: String) -> Worktree? {
    workspace.worktrees.first { ControlID.worktree($0.id) == id }
  }

  /// `reply` in the worktree named, else the one in view; refused where there is none.
  func replyingInWorktree(
    _ id: String?,
    _ reply: (Worktree) async -> ControlReply,
  ) async -> ControlReply {
    let named = id.map { worktree(withControlID: $0) } ?? worktreeInView
    guard let worktree = named else {
      return .refused(id.map { .noWorktree(id: $0) } ?? .nothingInView)
    }
    return await reply(worktree)
  }
}
