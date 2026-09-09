import Foundation

/// Whether a worktree's branch has already landed on its project's default
/// branch, and on what evidence.
///
/// Runtime state, not persisted, like `WorktreeStatus`: it is recomputed
/// from git, so a badge can never come off disk describing a branch that has
/// moved since.
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
    /// The branch tracked a remote branch that is no longer there, and the
    /// base has moved on without it. What "delete branch on merge" leaves
    /// behind, and the only trace a squash merge leaves that can be read
    /// without writing to the object database. Not proof: a pull request
    /// closed without merging leaves exactly the same thing.
    ///
    /// What is asked beside the gone upstream is not decoration. The base
    /// having moved on, because a branch cut under a name used before
    /// inherits the old branch's `branch.<name>` config and so tracks an
    /// upstream that was never there, which git reports as gone in the very
    /// same words. And the branch's changes reading the same on the base,
    /// because a branch whose upstream is gone is ahead of nothing, so work
    /// committed here after the squash landed is work `showsBadge` cannot
    /// see to hide the badge for.
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

  /// The fact on its own, for a screen reader and as the first half of the
  /// row's tooltip. Empty for a branch that has not landed, which shows
  /// nothing at all.
  public var summary: String {
    guard case .merged(let evidence, let base) = self else { return "" }
    switch evidence {
    case .ancestor: return "Merged into \(base)"
    case .patchEquivalent: return "Merged into \(base), rebased"
    case .upstreamGone: return "Its upstream branch is gone from the remote"
    }
  }

  /// Whether the row draws the badge at all, given what `git status` says
  /// about the same worktree.
  ///
  /// Uncommitted files and commits the upstream has not got hide it. Both
  /// are work that would go to the Trash with the directory, and telling
  /// someone a worktree can go while their work is still only in it is the
  /// one thing this badge must never do. A status not yet read shows the
  /// badge: the first poll is a moment away, and it will hide it.
  public func showsBadge(with status: WorktreeStatus?) -> Bool {
    guard isMerged else { return false }
    guard let status else { return true }
    return !status.isDirty && status.ahead == 0
  }

  /// The row's tooltip. "Safe to remove" only where the evidence is proof;
  /// the badge is not drawn at all where there is work to lose.
  public var help: String {
    guard isMerged else { return "" }
    return isCertain ? summary + " · safe to remove" : summary
  }

  /// What the removal dialog adds about the branch it is offering to
  /// delete, or `nil` when it has nothing to add.
  public func removalNote(branch: String) -> String? {
    guard case .merged(let evidence, let base) = self else { return nil }
    switch evidence {
    case .ancestor, .patchEquivalent:
      return "\(branch) is merged into \(base)."
    case .upstreamGone:
      return
        "\(branch) tracked a remote branch that is gone, so it was likely squash-merged. Check before deleting it: a closed pull request leaves the same trace."
    }
  }

  /// Whether a badge could ever apply to this worktree, `base` being the
  /// branch name the project's default ref points at. The trunk is not
  /// merged into itself, a bare repository has no checkout, a detached HEAD
  /// has no branch to delete, and the main worktree cannot be removed.
  public static func applies(to worktree: Worktree, base: String?) -> Bool {
    guard !worktree.isBare, !worktree.isPrimary, let own = worktree.branch else { return false }
    return own != base
  }
}
