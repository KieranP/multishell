import Foundation

/// What one `for-each-ref` answers: each branch's last commit date, and
/// where a default branch resolved, the merge inputs. Dates come back either way.
public struct BranchScan: Hashable, Sendable {
  /// The last commit on each local branch, by the name a worktree has as
  /// its own branch. A branch whose ref carried no date is absent.
  public let lastCommits: [String: Date]
  /// `nil` for a repository with no branch to measure merges against; see
  /// `DefaultBranch.resolve`.
  public let mergeInputs: MergeInputs?

  /// `override` is the project's `defaultBranch` setting, `nil` to detect.
  init(refs: [BranchRef], defaultBranch override: String?) {
    lastCommits = Dictionary(
      refs.filter(\.isLocal).compactMap { ref in ref.committedAt.map { (ref.shortName, $0) } },
      uniquingKeysWith: { first, _ in first })
    mergeInputs = DefaultBranch.resolve(from: refs, override: override)
      .map { MergeInputs(base: $0, refs: refs) }
  }
}
