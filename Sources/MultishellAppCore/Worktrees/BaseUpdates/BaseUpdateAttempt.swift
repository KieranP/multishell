/// How a run of Merge from Base or Rebase onto Base went, for the click and the
/// command line to answer each in its own way.
enum BaseUpdateAttempt {
  /// A reason the consent did not cover appeared, found after the fetch.
  case asks(PendingBaseUpdate)
  /// The task was cancelled, as a command line hanging up does, before git wrote.
  case cancelled
  /// git failed, its alert presented where the worktree is still there.
  case failed
  /// Another step about the base runs there, or a create or removal.
  case notStarted
  case ran(BaseUpdateRun)
  case refused(BaseUpdateRefusal)
}
