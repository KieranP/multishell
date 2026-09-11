import Foundation

/// Whether a worktree's branch has landed, and on what evidence. Runtime
/// only, so no badge comes off disk; see docs/design/merged-branch.md.
public enum WorktreeMergeState: Hashable, Sendable {
  /// Nothing has been asked yet, or the project has no default branch to
  /// measure against.
  case unknown
  case unmerged
  /// Landed on `base`, which is a ref name such as `origin/main`.
  case merged(Evidence, into: String)

  /// How the branch was found to have landed. The first two are proof; the
  /// third is inference, and `isCertain` is what tells them apart.
  public enum Evidence: Hashable, Sendable {
    /// Every commit is reachable from the base: a merge commit, or a
    /// fast-forward.
    case ancestor
    /// The base has an equivalent patch for every commit on the branch:
    /// how a rebase-merge or a run of cherry-picks lands.
    case patchEquivalent
    /// Upstream gone and the base moved on: what a squash merge leaves.
    /// Not proof; see docs/design/merged-branch.md for what else is asked.
    case upstreamGone
  }

  public var isMerged: Bool {
    if case .merged = self { return true }
    return false
  }

  /// Whether the evidence is proof rather than inference. Only these lead
  /// the removal dialog with deleting the branch; see `PendingWorktreeRemoval`.
  public var isCertain: Bool {
    guard case .merged(let evidence, _) = self else { return false }
    return evidence != .upstreamGone
  }

  /// The fact on its own, for a screen reader and the row's tooltip. Empty
  /// for a branch that has not landed.
  public var summary: String {
    guard case .merged(let evidence, let base) = self else { return "" }
    switch evidence {
    case .ancestor: return t("merged.into", base)
    case .patchEquivalent: return t("merged.into-rebased", base)
    case .upstreamGone: return t("merged.upstream-gone")
    }
  }

  /// Whether the row draws the badge, given `git status`. Uncommitted work
  /// hides it; see docs/design/merged-branch.md.
  public func showsBadge(with status: WorktreeStatus?) -> Bool {
    guard isMerged else { return false }
    guard let status else { return true }
    return !status.isDirty && status.ahead == 0
  }

  /// The row's tooltip. "Safe to remove" only where the evidence is proof;
  /// the badge is not drawn at all where there is work to lose.
  public var help: String {
    guard isMerged else { return "" }
    return isCertain ? t("merged.safe-to-remove", summary) : summary
  }

  /// What the removal dialog adds about the branch it is offering to
  /// delete, or `nil` when it has nothing to add.
  public func removalNote(branch: String) -> String? {
    guard case .merged(let evidence, let base) = self else { return nil }
    switch evidence {
    case .ancestor, .patchEquivalent:
      return t("merged.removal-note", branch, base)
    case .upstreamGone:
      return t("merged.removal-note-upstream-gone", branch)
    }
  }

  /// Whether a badge could ever apply: not the trunk, a bare repository, a
  /// detached HEAD, or the main worktree.
  public static func applies(to worktree: Worktree, base: String?) -> Bool {
    guard !worktree.isBare, !worktree.isPrimary, let own = worktree.branch else { return false }
    return own != base
  }
}
