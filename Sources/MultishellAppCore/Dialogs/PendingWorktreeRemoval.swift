import MultishellCore

/// A worktree removal waiting on the confirmation dialog, and what that
/// dialog says and offers about the branch.
///
/// Two global settings shape the request: whether removal asks at all, and
/// whether the branch always goes with the worktree. When the branch is not
/// decided by a setting the dialog asks, even for a person who turned the
/// confirmation off: deleting a branch is the one part that cannot be undone
/// from the sidebar.
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
  /// Whether the branch has already landed on the project's default branch,
  /// which decides which button the dialog leads with and adds a line to
  /// what it says.
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
  public var title: String { "Remove worktree \(customName ?? worktree.name)?" }

  /// The one button when the branch is decided; the keep-branch button when
  /// the dialog asks, beside `removeWithBranchLabel`.
  public var removeLabel: String {
    if case .decided(deletes: true) = branch { return removeWithBranchLabel }
    return "Remove Worktree"
  }

  public var removeWithBranchLabel: String { "Remove Worktree and Branch" }

  /// The remove buttons in the order the dialog shows them; the first is
  /// the one it leads with.
  ///
  /// A branch already merged leads with deleting it, since by then keeping
  /// it is the unusual choice. Only on evidence that is proof: an upstream
  /// that has gone is left the same way by a pull request closed without
  /// merging, and that branch is the only copy of the work.
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
    var notes = ["Moves \(worktree.path.path) to the Trash and prunes it from git."]
    if let name = worktree.branch {
      switch branch {
      case .asks: notes.append("The branch \(name) is kept unless you remove it too.")
      case .decided(deletes: true): notes.append("The branch \(name) is deleted with it.")
      case .decided(deletes: false): notes.append("The branch \(name) is kept.")
      }
    }
    if let name = worktree.branch, let note = mergeState.removalNote(branch: name) {
      notes.append(note)
    }
    if let warning { notes.append(warning) }
    return notes.joined(separator: "\n\n")
  }

  /// What the confirmation warns about beyond the removal itself: the
  /// uncommitted files the status badge counted, which go to the Trash with
  /// the directory, and the shells still running there. `nil` when there is
  /// nothing to add.
  public static func warning(changedFiles: Int, liveTerminals: Int) -> String? {
    var notes: [String] = []
    if changedFiles > 0 {
      let files = Wording.count(changedFiles, "changed file")
      notes.append("It has \(files), kept in the Trash with the directory.")
    }
    if liveTerminals > 0 {
      notes.append("\(Wording.count(liveTerminals, "open terminal")) will be closed.")
    }
    return notes.isEmpty ? nil : notes.joined(separator: " ")
  }
}
