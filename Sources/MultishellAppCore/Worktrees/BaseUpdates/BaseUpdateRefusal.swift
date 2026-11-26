import MultishellCore

/// Why a worktree refuses a merge or rebase from its base, read afresh: the menu
/// presents it as an alert, `worktrees update` answers with it as data.
enum BaseUpdateRefusal: Error {
  /// The branch or base moved under a stale menu, a fetch or a question.
  case baseChanged(to: String?)
  case branchMoved(to: String)
  /// The worktree went while git was read.
  case gone
  case pickingCommits
  /// Never stashed: an agent may be mid-edit, and the stash is every worktree's.
  case uncommittedChanges([String])
  case unfinishedUpdate(UpdateMethod)
  /// git could not say, which refuses too.
  case unreadable(any Error)
}
