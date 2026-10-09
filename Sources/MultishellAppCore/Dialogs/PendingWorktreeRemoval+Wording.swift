import MultishellCore
import MultishellGitKit

extension PendingWorktreeRemoval {
  /// The row the user right-clicked, by the name that row shows. The branch
  /// is not lost: `message` names it under this.
  public var title: String {
    t("worktree-removal.title", customName ?? worktree.name)
  }

  var removeLabel: String { t("worktree-removal.remove") }

  var removeWithBranchLabel: String { t("worktree-removal.remove-with-branch") }

  /// Names the worktree as the title does and where it goes, says what
  /// happens to the branch, then what the status badge and shell count know.
  public func message(warning: String?) -> String {
    let name = customName ?? worktree.name
    var notes = [
      trashes ? t("worktree-removal.moves", name) : t("worktree-removal.deletes", name)
    ]
    if let branch = worktree.branch {
      switch branchHandling {
      case .offersBoth: notes.append(t("worktree-removal.branch-asked", branch))
      case .decided(deletesBranch: true): notes.append(t("worktree-removal.branch-deleted", branch))
      case .decided(deletesBranch: false): notes.append(t("worktree-removal.branch-kept", branch))
      }
    }
    if let branch = worktree.branch, let note = mergeState.removalNote(branch: branch) {
      notes.append(note)
    }
    if let warning { notes.append(warning) }
    return notes.joined(separator: "\n\n")
  }

  /// What the confirmation warns about beyond the removal: uncommitted files,
  /// or that they went unread, and the shells still running there.
  static func warning(
    changedFiles: Int, isStatusUnread: Bool = false, liveTerminals: Int, trashes: Bool = true
  )
    -> String?
  {
    var notes: [String] = []
    if isStatusUnread {
      notes.append(trashes ? t("removal.changes-unread") : t("removal.changes-unread-deleted"))
    } else if changedFiles > 0 {
      notes.append(
        trashes
          ? t("removal.changed-files", changedFiles)
          : t("removal.changed-files-deleted", changedFiles))
    }
    if liveTerminals > 0 {
      notes.append(t("removal.terminals-closed", liveTerminals))
    }
    return notes.isEmpty ? nil : notes.joined(separator: " ")
  }
}
