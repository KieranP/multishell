import MultishellGitKit

/// A create or remove running on a worktree, and the stage it is in. Shown
/// in the detail pane in place of the terminals and as a spinner on the
/// sidebar row, so neither the sheet nor the dialog has to stay up while a
/// slow hook runs, and another worktree can be created meanwhile.
///
/// Only the pre-create hook and `git worktree add` still run under the
/// sheet: until they finish there is no worktree to show.
///
/// A hook that fails while the worktree is still there, the post-create
/// hook or a pre-delete veto, leaves the entry in place with `failure` set:
/// the pane shows what the hook said until the user dismisses it. An alert
/// would go up over whatever the user had moved on to, or be lost under the
/// sheet's own dismissal when the hook fails at once.
struct WorktreeOperation: Equatable {
  enum Step: Equatable {
    case postCreateHook
    case preDeleteHook
    case removingWorktree
    case postDeleteHook
    case deletingBranch
  }

  let step: Step
  /// What the hook or git said, once the stage has failed. `nil` while it
  /// runs.
  var failure: String?

  init(_ step: Step, failure: String? = nil) {
    self.step = step
    self.failure = failure
  }

  init(_ step: WorktreeRemovalStep) {
    switch step {
    case .preDeleteHook: self.step = .preDeleteHook
    case .removingWorktree: self.step = .removingWorktree
    case .postDeleteHook: self.step = .postDeleteHook
    case .deletingBranch: self.step = .deletingBranch
    }
  }

  var isRemoval: Bool { step != .postCreateHook }

  var isRunning: Bool { failure == nil }

  var title: String {
    if failure != nil {
      switch step {
      case .postCreateHook: return "The post-create hook failed"
      case .preDeleteHook: return "The pre-delete hook refused the removal"
      case .removingWorktree: return "git worktree remove failed"
      case .postDeleteHook: return "The post-delete hook failed"
      case .deletingBranch: return "The branch was not deleted"
      }
    }
    switch step {
    case .postCreateHook: return "Running the post-create hook…"
    case .preDeleteHook: return "Running the pre-delete hook…"
    case .removingWorktree: return "Running git worktree remove…"
    case .postDeleteHook: return "Running the post-delete hook…"
    case .deletingBranch: return "Deleting the branch…"
    }
  }

  /// What the pane says under the title: what happens here when it ends,
  /// or where things stand after a failure.
  var detail: String {
    if failure != nil {
      switch step {
      case .postCreateHook:
        return "The worktree was created. Dismiss to open its first terminal."
      case .preDeleteHook:
        return "The worktree and its terminals stay. Dismiss to go back to them."
      case .removingWorktree, .postDeleteHook, .deletingBranch:
        return "Dismiss to go back to the terminals."
      }
    }
    switch step {
    case .postCreateHook: return "The first terminal opens here when it finishes."
    case .preDeleteHook: return "The worktree stays if the hook refuses."
    case .removingWorktree, .postDeleteHook, .deletingBranch:
      return "Its terminals close when it is gone."
    }
  }
}
