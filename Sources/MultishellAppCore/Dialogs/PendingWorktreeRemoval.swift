import Foundation
import MultishellCore

/// A worktree removal waiting on its dialog. The branch question is asked
/// even where confirmation is off, being the one part with no undo.
public struct PendingWorktreeRemoval: Identifiable, Equatable, Sendable {
  enum BranchHandling: Equatable, Sendable {
    /// Settled before the dialog: the worktree is detached, or the setting
    /// deletes the branch every time.
    case decided(deletes: Bool)
    /// The dialog offers both.
    case asks
  }

  /// How a removal request proceeds under the settings.
  enum Decision: Equatable, Sendable {
    case remove(deletingBranch: Bool)
    case ask(PendingWorktreeRemoval)
  }

  /// One of the dialog's remove buttons.
  public struct Choice: Equatable, Sendable {
    public let label: String
    public let deletesBranch: Bool

    init(label: String, deletesBranch: Bool) {
      self.label = label
      self.deletesBranch = deletesBranch
    }
  }

  public let worktree: Worktree
  let branchHandling: BranchHandling
  /// The name the user gave this worktree, or `nil` for none.
  let customName: String?
  /// Whether the branch has landed, which decides the button the dialog
  /// leads with and adds a line to what it says.
  let mergeState: WorktreeMergeState
  /// Whether the directory goes to the Trash or is deleted outright.
  let trashes: Bool

  init(
    worktree: Worktree, branchHandling: BranchHandling, customName: String? = nil,
    mergeState: WorktreeMergeState = .unknown, trashes: Bool = true
  ) {
    self.worktree = worktree
    self.branchHandling = branchHandling
    self.customName = customName
    self.mergeState = mergeState
    self.trashes = trashes
  }

  public var id: String { worktree.id }

  /// The row the user right-clicked, by the name that row shows. The branch
  /// is not lost: `message` names it under this.
  public var title: String {
    t("worktree-removal.title", customName ?? worktree.name)
  }

  /// The one button when the branch is decided; the keep-branch button when
  /// the dialog asks, beside `removeWithBranchLabel`.
  var primaryRemoveLabel: String {
    if case .decided(deletes: true) = branchHandling { return removeWithBranchLabel }
    return t("worktree-removal.remove")
  }

  var removeWithBranchLabel: String { t("worktree-removal.remove-with-branch") }

  /// The remove buttons in the order the dialog shows them. A merged branch
  /// leads with deleting it, and only on evidence that is proof.
  public var choices: [Choice] {
    switch branchHandling {
    case .decided(let deletes):
      return [Choice(label: primaryRemoveLabel, deletesBranch: deletes)]
    case .asks:
      let keep = Choice(label: primaryRemoveLabel, deletesBranch: false)
      let delete = Choice(label: removeWithBranchLabel, deletesBranch: true)
      return mergeState.isCertain ? [delete, keep] : [keep, delete]
    }
  }

  static func decide(
    _ worktree: Worktree, customName: String? = nil, confirms: Bool, alwaysDeletesBranch: Bool,
    trashes: Bool = true, mergeState: WorktreeMergeState = .unknown
  ) -> Decision {
    let hasBranch = worktree.branch != nil
    let deletes = hasBranch && alwaysDeletesBranch
    let asksAboutBranch = hasBranch && !alwaysDeletesBranch
    guard confirms || asksAboutBranch else { return .remove(deletingBranch: deletes) }
    return .ask(
      PendingWorktreeRemoval(
        worktree: worktree, branchHandling: asksAboutBranch ? .asks : .decided(deletes: deletes),
        customName: customName, mergeState: mergeState, trashes: trashes))
  }

  /// Names the worktree as the title does and where it goes, says what
  /// happens to the branch, then what the status badge and shell count know.
  public func message(warning: String?) -> String {
    let name = customName ?? worktree.name
    var notes = [
      trashes ? t("worktree-removal.moves", name) : t("worktree-removal.deletes", name)
    ]
    if let name = worktree.branch {
      switch branchHandling {
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
  /// bound for the Trash or deletion, and the shells still running there.
  static func warning(
    changedFiles: Int, liveTerminals: Int, trashes: Bool = true
  )
    -> String?
  {
    var notes: [String] = []
    if changedFiles > 0 {
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
