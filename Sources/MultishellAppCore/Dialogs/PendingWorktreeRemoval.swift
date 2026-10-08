import Foundation
import MultishellCore
import MultishellGitKit

/// A worktree removal waiting on its dialog. The branch question is asked
/// even where confirmation is off, being the one part with no undo.
public struct PendingWorktreeRemoval: Identifiable, Equatable, Sendable {
  enum BranchHandling: Equatable, Sendable {
    /// Settled before the dialog: the worktree is detached, or the setting
    /// deletes the branch every time.
    case decided(deletesBranch: Bool)
    /// The dialog offers both.
    case offersBoth
  }

  /// How a removal request proceeds under the settings.
  enum Decision: Equatable, Sendable {
    case remove(deletesBranch: Bool)
    case ask(PendingWorktreeRemoval)
  }

  /// One of the dialog's remove buttons.
  public struct Choice: Equatable, Sendable {
    public let label: String
    let deletesBranch: Bool
  }

  let worktree: Worktree
  let branchHandling: BranchHandling
  let customName: String?
  /// Whether the branch has landed, which decides the button the dialog
  /// leads with and adds a line to what it says.
  let mergeState: WorktreeMergeState
  /// Whether the directory goes to the Trash or is deleted outright.
  let trashes: Bool
  /// The status read had not answered when the dialog was built, so the
  /// changed files it would count are unknown.
  let hasUnreadChanges: Bool

  init(
    worktree: Worktree, branchHandling: BranchHandling, customName: String? = nil,
    mergeState: WorktreeMergeState = .unknown, trashes: Bool = true, hasUnreadChanges: Bool = false
  ) {
    self.worktree = worktree
    self.branchHandling = branchHandling
    self.customName = customName
    self.mergeState = mergeState
    self.trashes = trashes
    self.hasUnreadChanges = hasUnreadChanges
  }

  public var id: String { worktree.id }

  /// The remove buttons in the order the dialog shows them. A merged branch
  /// leads with deleting it, and only on evidence that is proof.
  public var choices: [Choice] {
    switch branchHandling {
    case .decided(let deletesBranch):
      let label = deletesBranch ? removeWithBranchLabel : removeLabel
      return [Choice(label: label, deletesBranch: deletesBranch)]
    case .offersBoth:
      let keep = Choice(label: removeLabel, deletesBranch: false)
      let delete = Choice(label: removeWithBranchLabel, deletesBranch: true)
      return mergeState.isCertain ? [delete, keep] : [keep, delete]
    }
  }

  static func decide(
    _ worktree: Worktree, customName: String? = nil, confirms: Bool, alwaysDeletesBranch: Bool,
    trashes: Bool = true, mergeState: WorktreeMergeState = .unknown, hasUnreadChanges: Bool = false
  ) -> Decision {
    let hasBranch = worktree.branch != nil
    let deletes = hasBranch && alwaysDeletesBranch
    let asksAboutBranch = hasBranch && !alwaysDeletesBranch
    guard confirms || asksAboutBranch else { return .remove(deletesBranch: deletes) }
    return .ask(
      PendingWorktreeRemoval(
        worktree: worktree,
        branchHandling: asksAboutBranch ? .offersBoth : .decided(deletesBranch: deletes),
        customName: customName, mergeState: mergeState, trashes: trashes,
        hasUnreadChanges: hasUnreadChanges))
  }
}
