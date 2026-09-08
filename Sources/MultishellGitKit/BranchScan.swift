import Foundation
import MultishellCore

/// What one `for-each-ref` over a repository answers.
///
/// Two questions come off the same read: when each local branch was last
/// committed to, which the sidebar's last-commit orders go by, and —
/// where a default branch could be resolved — the merge scan. The dates
/// come back either way, because a repository with no trunk to measure
/// against still has branches the sidebar can order.
///
/// Pure: built from refs, so both answers are tested without git.
public struct BranchScan: Hashable, Sendable {
  /// The last commit on each local branch, by the name a worktree has as
  /// its own branch. A branch whose ref carried no date is absent.
  public let lastCommits: [String: Date]
  /// `nil` for a repository with no branch to measure merges against; see
  /// `DefaultBranch.resolve`.
  public let merges: MergeScan?

  /// `override` is the project's `defaultBranch` setting, `nil` to detect.
  public init(refs: [BranchRef], defaultBranch override: String?) {
    lastCommits = Dictionary(
      refs.filter(\.isLocal).compactMap { ref in ref.committedAt.map { (ref.shortName, $0) } },
      uniquingKeysWith: { first, _ in first })
    merges = DefaultBranch.resolve(from: refs, override: override)
      .map { MergeScan(base: $0, refs: refs) }
  }
}
