import MultishellCore
import MultishellGitKit

extension WorktreeOperation {
  public enum Step: Equatable, Sendable {
    case linkingFiles
    case copyingFiles
    case postCreateHook
    case preDeleteHook
    case removingWorktree
    case deletingWorktree
    case postDeleteHook
    case deletingBranch

    init(_ placement: WorktreeFilePlacement) {
      switch placement {
      case .link: self = .linkingFiles
      case .copy: self = .copyingFiles
      }
    }

    init(_ removal: WorktreeRemovalStep, trashes: Bool = true) {
      switch removal {
      case .preDeleteHook: self = .preDeleteHook
      case .removingWorktree: self = trashes ? .removingWorktree : .deletingWorktree
      case .postDeleteHook: self = .postDeleteHook
      case .deletingBranch: self = .deletingBranch
      }
    }

    /// A stage of a create: the worktree is there, and its first terminal
    /// is held back until this ends or its failure is dismissed.
    var isCreation: Bool {
      self == .linkingFiles || self == .copyingFiles || self == .postCreateHook
    }

    /// What the pane's Cancel does at this stage, `nil` where it has none.
    /// One property, so a stage cannot offer the button and say nothing.
    public var cancelHelp: String? {
      switch self {
      case .linkingFiles, .copyingFiles: return t("step.cancel-files-help")
      case .postCreateHook, .preDeleteHook, .postDeleteHook: return t("step.cancel-hook-help")
      case .removingWorktree, .deletingWorktree, .deletingBranch: return nil
      }
    }
  }
}
