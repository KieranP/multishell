import MultishellCore

/// A worktree removal waiting on its dialog. The branch question is asked
/// even where confirmation is off, being the one part with no undo.
public struct PendingWorktreeRemoval: Identifiable, Equatable, Sendable {
  public enum BranchChoice: Equatable, Sendable {
    /// Settled before the dialog: the worktree is detached, or the setting
    /// deletes the branch every time.
    case decided(deletes: Bool)
    /// The dialog offers both.
    case asks
  }

  /// How a removal request proceeds under the settings.
  public enum Decision: Equatable, Sendable {
    case remove(deletingBranch: Bool)
    case ask(PendingWorktreeRemoval)
  }

  /// One of the dialog's remove buttons.
  public struct Choice: Equatable, Sendable {
    public let label: String
    public let deletesBranch: Bool

    public init(label: String, deletesBranch: Bool) {
      self.label = label
      self.deletesBranch = deletesBranch
    }
  }

  public let worktree: Worktree
  public let branch: BranchChoice
  /// The name the user gave this worktree, or `nil` for none.
  public let customName: String?
  /// Whether the branch has landed, which decides the button the dialog
  /// leads with and adds a line to what it says.
  public let mergeState: WorktreeMergeState

  public init(
    worktree: Worktree, branch: BranchChoice, customName: String? = nil,
    mergeState: WorktreeMergeState = .unknown
  ) {
    self.worktree = worktree
    self.branch = branch
    self.customName = customName
    self.mergeState = mergeState
  }

  public var id: String { worktree.id }

  /// The row the user right-clicked, by the name that row shows. The branch
  /// is not lost: `message` names it, and the path, under this.
  public var title: String {
    t("worktree-removal.title", customName ?? worktree.name)
  }

  /// The one button when the branch is decided; the keep-branch button when
  /// the dialog asks, beside `removeWithBranchLabel`.
  public var removeLabel: String {
    if case .decided(deletes: true) = branch { return removeWithBranchLabel }
    return t("worktree-removal.remove")
  }

  public var removeWithBranchLabel: String { t("worktree-removal.remove-with-branch") }

  /// The remove buttons in the order the dialog shows them. A merged branch
  /// leads with deleting it, and only on evidence that is proof.
  public var choices: [Choice] {
    switch branch {
    case .decided(let deletes):
      return [Choice(label: removeLabel, deletesBranch: deletes)]
    case .asks:
      let keep = Choice(label: removeLabel, deletesBranch: false)
      let delete = Choice(label: removeWithBranchLabel, deletesBranch: true)
      return mergeState.isCertain ? [delete, keep] : [keep, delete]
    }
  }

  /// What confirming the first button deletes.
  public var deletesBranch: Bool { branch == .decided(deletes: true) }

  public static func decide(
    _ worktree: Worktree, customName: String? = nil, confirms: Bool, alwaysDeletesBranch: Bool,
    mergeState: WorktreeMergeState = .unknown
  ) -> Decision {
    let hasBranch = worktree.branch != nil
    let deletes = hasBranch && alwaysDeletesBranch
    let branchIsOpen = hasBranch && !alwaysDeletesBranch
    guard confirms || branchIsOpen else { return .remove(deletingBranch: deletes) }
    return .ask(
      PendingWorktreeRemoval(
        worktree: worktree, branch: branchIsOpen ? .asks : .decided(deletes: deletes),
        customName: customName, mergeState: mergeState))
  }

  /// Names the path and where it goes, says what happens to the branch,
  /// then whatever the status badge and live-shell count know.
  public func message(warning: String?) -> String {
    var notes = [t("worktree-removal.moves", worktree.path.path)]
    if let name = worktree.branch {
      switch branch {
      case .asks: notes.append(t("worktree-removal.branch-asked", name))
      case .decided(deletes: true): notes.append(t("worktree-removal.branch-deleted", name))
      case .decided(deletes: false): notes.append(t("worktree-removal.branch-kept", name))
      }
    }
    if let name = worktree.branch, let note = mergeState.removalNote(branch: name) {
      notes.append(note)
    }
    if let warning { notes.append(warning) }
    return notes.joined(separator: "\n\n")
  }

  /// What the confirmation warns about beyond the removal: uncommitted files
  /// bound for the Trash, and the shells still running there.
  public static func warning(changedFiles: Int, liveTerminals: Int) -> String? {
    var notes: [String] = []
    if changedFiles > 0 {
      notes.append(t("removal.changed-files", changedFiles))
    }
    if liveTerminals > 0 {
      notes.append(t("removal.terminals-closed", liveTerminals))
    }
    return notes.isEmpty ? nil : notes.joined(separator: " ")
  }
}
