import MultishellCore

/// One worktree as `multishell worktrees list` prints it, by its `ControlID`
/// and its project's.
struct WorktreeEntry: Encodable, Equatable {
  let id: String
  let project: String
  let name: String
  let path: String
  let branch: String?
  let isPrimary: Bool
  let isInView: Bool
  let isBusy: Bool
  /// The dot on its row, `nil` for none.
  let state: SessionState?
  let tabCount: Int
}
