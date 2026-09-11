import MultishellCore
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
/// A stage that fails while the worktree is still there, a file list, the
/// post-create hook or a pre-delete veto, leaves the entry with `failure`:
/// the pane shows what went wrong until the user dismisses it. An alert
/// would go up over whatever the user had moved on to, or be lost under the
/// sheet's own dismissal when the hook fails at once.
public struct WorktreeOperation: Equatable, Sendable {
  public enum Step: Equatable, Sendable {
    case linkingFiles
    case copyingFiles
    case postCreateHook
    case preDeleteHook
    case removingWorktree
    case postDeleteHook
    case deletingBranch

    public init(_ placement: WorktreePlacement) {
      switch placement {
      case .link: self = .linkingFiles
      case .copy: self = .copyingFiles
      }
    }

    public init(_ removal: WorktreeRemovalStep) {
      switch removal {
      case .preDeleteHook: self = .preDeleteHook
      case .removingWorktree: self = .removingWorktree
      case .postDeleteHook: self = .postDeleteHook
      case .deletingBranch: self = .deletingBranch
      }
    }

    /// A stage of a create: the worktree is there, and its first terminal
    /// is held back until this ends or its failure is dismissed.
    public var isCreation: Bool {
      self == .linkingFiles || self == .copyingFiles || self == .postCreateHook
    }

    /// What the pane's Cancel does at this stage, and `nil` for a stage
    /// that has none: git's own are quick and are left to finish. One
    /// property, so a stage cannot offer the button and say nothing about
    /// it; the word on it is the same everywhere, and what it means is
    /// not, a hook being ended and a list being given up on.
    public var cancelHelp: String? {
      switch self {
      case .linkingFiles, .copyingFiles: return t("step.cancel-files-help")
      case .postCreateHook, .preDeleteHook, .postDeleteHook: return t("step.cancel-hook-help")
      case .removingWorktree, .deletingBranch: return nil
      }
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
      case .linkingFiles: return t("step.files-not-linked")
      case .copyingFiles: return t("step.files-not-copied")
      case .postCreateHook:
        return timedOut
          ? t("step.post-create-hook-timed-out") : t("step.post-create-hook-failed")
      case .preDeleteHook:
        return timedOut
          ? t("step.pre-delete-hook-timed-out") : t("step.pre-delete-hook-refused")
      case .removingWorktree: return t("step.worktree-not-removed")
      case .postDeleteHook: return t("step.post-delete-hook-failed")
      case .deletingBranch: return t("step.branch-not-deleted")
      }
    }
    switch step {
    case .linkingFiles: return t("step.linking-files")
    case .copyingFiles: return t("step.copying-files")
    case .postCreateHook: return t("step.post-create-hook")
    case .preDeleteHook: return t("step.pre-delete-hook")
    case .removingWorktree: return t("step.removing-worktree")
    case .postDeleteHook: return t("step.post-delete-hook")
    case .deletingBranch: return t("step.deleting-branch")
    }
  }

  /// What the pane says under the title: what happens here when it ends,
  /// or where things stand after a failure.
  public var detail: String {
    if failure != nil {
      switch step {
      case .linkingFiles, .copyingFiles:
        // Not "the hook did not run": a project may list files and have no
        // hook, and this is the pane for that one too.
        return t("step.files-failed-detail")
      case .postCreateHook: return t("step.post-create-failed-detail")
      case .preDeleteHook: return t("step.pre-delete-failed-detail")
      case .removingWorktree, .postDeleteHook, .deletingBranch:
        return t("step.removal-failed-detail")
      }
    }
    switch step {
    case .linkingFiles, .copyingFiles, .postCreateHook: return t("step.creation-detail")
    case .preDeleteHook: return t("step.pre-delete-detail")
    case .removingWorktree, .postDeleteHook, .deletingBranch: return t("step.removal-detail")
    }
  }
}
