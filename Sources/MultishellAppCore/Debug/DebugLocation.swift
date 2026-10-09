/// Where a debug row's processes or git run were, as the sidebar names it.
struct DebugLocation: Sendable, Equatable {
  /// `nil` for a directory in no worktree, named by its own last component.
  let projectName: String?
  let worktreeName: String
}
