import MultishellCore

/// A worktree removal waiting on the confirmation dialog, and what that
/// dialog says and offers about the branch.
///
/// Two global settings shape the request: whether removal asks at all, and
/// whether the branch always goes with the worktree. When the branch is not
/// decided by a setting the dialog asks, even for a person who turned the
/// confirmation off: deleting a branch is the one part that cannot be undone
/// from the sidebar.
struct PendingWorktreeRemoval: Identifiable, Equatable {
  enum BranchChoice: Equatable {
    /// Settled before the dialog: the worktree is detached, or the setting
    /// deletes the branch every time.
    case decided(deletes: Bool)
    /// The dialog offers both.
    case asks
  }

  /// How a removal request proceeds under the settings.
  enum Decision: Equatable {
    case remove(deletingBranch: Bool)
    case ask(PendingWorktreeRemoval)
  }

  let worktree: Worktree
  let branch: BranchChoice

  var id: String { worktree.id }

  var title: String { "Remove worktree \(worktree.name)?" }

  /// The one button when the branch is decided; the keep-branch button when
  /// the dialog asks, beside `removeWithBranchLabel`.
  var removeLabel: String {
    if case .decided(deletes: true) = branch { return removeWithBranchLabel }
    return "Remove Worktree"
  }

  var removeWithBranchLabel: String { "Remove Worktree and Branch" }

  var offersBranchDeletion: Bool { branch == .asks }

  /// What confirming the first button deletes.
  var deletesBranch: Bool { branch == .decided(deletes: true) }

  static func decide(
    _ worktree: Worktree, confirms: Bool, alwaysDeletesBranch: Bool
  ) -> Decision {
    let hasBranch = worktree.branch != nil
    let deletes = hasBranch && alwaysDeletesBranch
    let branchIsOpen = hasBranch && !alwaysDeletesBranch
    guard confirms || branchIsOpen else { return .remove(deletingBranch: deletes) }
    return .ask(
      PendingWorktreeRemoval(
        worktree: worktree, branch: branchIsOpen ? .asks : .decided(deletes: deletes)))
  }

  /// Names the path, says what happens to the branch, then whatever the
  /// status badge and live-shell count know.
  func message(warning: String?) -> String {
    var notes = ["Runs git worktree remove on \(worktree.path.path)."]
    if let name = worktree.branch {
      switch branch {
      case .asks: notes.append("The branch \(name) is kept unless you remove it too.")
      case .decided(deletes: true): notes.append("The branch \(name) is deleted with it.")
      case .decided(deletes: false): notes.append("The branch \(name) is kept.")
      }
    }
    if let warning { notes.append(warning) }
    return notes.joined(separator: "\n\n")
  }
}
