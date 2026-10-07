import MultishellCore

extension WorktreeOperation {
  public var title: String {
    if failure != nil {
      switch stage {
      case .linkingFiles: return t("step.files-not-linked")
      case .copyingFiles: return t("step.files-not-copied")
      case .postCreateHook:
        return didTimeOut
          ? t("step.post-create-hook-timed-out") : t("step.post-create-hook-failed")
      case .preDeleteHook:
        return didTimeOut
          ? t("step.pre-delete-hook-timed-out") : t("step.pre-delete-hook-refused")
      case .removingWorktree, .deletingWorktree: return t("step.worktree-not-removed")
      case .postDeleteHook: return t("step.post-delete-hook-failed")
      case .deletingBranch: return t("step.branch-not-deleted")
      }
    }
    switch stage {
    case .linkingFiles: return t("step.linking-files")
    case .copyingFiles: return t("step.copying-files")
    case .postCreateHook: return t("step.post-create-hook")
    case .preDeleteHook: return t("step.pre-delete-hook")
    case .removingWorktree: return t("step.removing-worktree")
    case .deletingWorktree: return t("step.deleting-worktree")
    case .postDeleteHook: return t("step.post-delete-hook")
    case .deletingBranch: return t("step.deleting-branch")
    }
  }

  /// What the pane says under the title: what happens here when it ends,
  /// or where things stand after a failure.
  public var detail: String {
    if failure != nil {
      switch stage {
      case .linkingFiles, .copyingFiles:
        // Not "the hook did not run": a project may list files and have no
        // hook, and this is the pane for that one too.
        return t("step.files-failed-detail")
      case .postCreateHook: return t("step.post-create-failed-detail")
      case .preDeleteHook: return t("step.pre-delete-failed-detail")
      case .removingWorktree, .deletingWorktree, .postDeleteHook, .deletingBranch:
        return t("step.removal-failed-detail")
      }
    }
    switch stage {
    case .linkingFiles, .copyingFiles, .postCreateHook: return t("step.creation-detail")
    case .preDeleteHook: return t("step.pre-delete-detail")
    case .removingWorktree: return t("step.removal-detail")
    case .deletingWorktree: return t("step.deletion-detail")
    case .postDeleteHook, .deletingBranch: return t("step.after-removal-detail")
    }
  }
}
