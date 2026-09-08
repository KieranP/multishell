import MultishellGitKit
import MultishellProcess

/// A create or remove running on a worktree, and the stage it is in. Shown
/// in the detail pane in place of the terminals and as a spinner on the
/// sidebar row, so neither the sheet nor the dialog has to stay up while a
/// slow hook runs, and another worktree can be created meanwhile.
///
/// Only the pre-create hook and `git worktree add` still run under the
/// sheet: until they finish there is no worktree to show.
///
/// A stage that fails while the worktree is still there, the copy, the
/// post-create hook or a pre-delete veto, leaves the entry with `failure`:
/// the pane shows what went wrong until the user dismisses it. An alert
/// would go up over whatever the user had moved on to, or be lost under the
/// sheet's own dismissal when the hook fails at once.
public struct WorktreeOperation: Equatable, Sendable {
  public enum Step: Equatable, Sendable {
    case copyingFiles
    case postCreateHook
    case preDeleteHook
    case removingWorktree
    case postDeleteHook
    case deletingBranch

    public init(_ removal: WorktreeRemovalStep) {
      switch removal {
      case .preDeleteHook: self = .preDeleteHook
      case .removingWorktree: self = .removingWorktree
      case .postDeleteHook: self = .postDeleteHook
      case .deletingBranch: self = .deletingBranch
      }
    }

    /// A stage the user can stop from the pane. Git's own stages are quick
    /// and are left to finish.
    public var isHook: Bool {
      self == .postCreateHook || self == .preDeleteHook || self == .postDeleteHook
    }
  }

  public let step: Step
  /// What the hook or git said, once the stage has failed. `nil` while it
  /// runs.
  public var failure: String?
  /// The stage failed because the hook ran past the timeout and was
  /// stopped, so the title says it did not finish rather than that it
  /// refused.
  public var timedOut = false

  public init(_ step: Step, failure: String? = nil, timedOut: Bool = false) {
    self.step = step
    self.failure = failure
    self.timedOut = timedOut
  }

  public init(_ step: WorktreeRemovalStep) {
    self.init(Step(step))
  }

  public var isRunning: Bool { failure == nil }

  public var title: String {
    if failure != nil {
      switch step {
      case .copyingFiles: return "Some files were not copied into the worktree"
      case .postCreateHook:
        return timedOut ? "The post-create hook did not finish" : "The post-create hook failed"
      case .preDeleteHook:
        return timedOut
          ? "The pre-delete hook did not finish" : "The pre-delete hook refused the removal"
      case .removingWorktree: return "The worktree could not be removed"
      case .postDeleteHook: return "The post-delete hook failed"
      case .deletingBranch: return "The branch was not deleted"
      }
    }
    switch step {
    case .copyingFiles: return "Copying files into the worktree…"
    case .postCreateHook: return "Running the post-create hook…"
    case .preDeleteHook: return "Running the pre-delete hook…"
    case .removingWorktree: return "Moving the worktree to the Trash…"
    case .postDeleteHook: return "Running the post-delete hook…"
    case .deletingBranch: return "Deleting the branch…"
    }
  }

  /// What the pane says under the title: what happens here when it ends,
  /// or where things stand after a failure.
  public var detail: String {
    if failure != nil {
      switch step {
      case .copyingFiles:
        // Not "the hook did not run": a project may list files and have no
        // hook, and this is the pane for that one too.
        return
          "The worktree was created, and nothing else ran in it. Dismiss to open its first terminal."
      case .postCreateHook:
        return "The worktree was created. Dismiss to open its first terminal."
      case .preDeleteHook:
        return "The worktree and its terminals stay. Dismiss to go back to them."
      case .removingWorktree, .postDeleteHook, .deletingBranch:
        return "Dismiss to go back to the terminals."
      }
    }
    switch step {
    case .copyingFiles: return "The first terminal opens here when it finishes."
    case .postCreateHook: return "The first terminal opens here when it finishes."
    case .preDeleteHook: return "The worktree stays if the hook refuses."
    case .removingWorktree, .postDeleteHook, .deletingBranch:
      return "Its terminals close when it is gone; the directory is in the Trash."
    }
  }
}
