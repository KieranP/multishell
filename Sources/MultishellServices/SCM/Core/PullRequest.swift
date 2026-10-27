import Foundation

/// One pull request as its host lists it. Runtime only, never saved: it is
/// read again from the host; see Docs/design/services.md.
public struct PullRequest: Hashable, Sendable {
  public let number: Int
  public let title: String
  public let url: URL
  public let state: PullRequestState
  public let review: PullRequestReview
  public let blocker: PullRequestBlocker?
  /// Whether the host has worked out if it conflicts: GitHub answers UNKNOWN
  /// for a while after a push to it or its base.
  public let hasConflictAnswer: Bool
  /// Auto-merge is on, so it merges once its checks and reviews allow.
  public let autoMergesWhenReady: Bool
  /// Open, and the host would merge it now: its checks and reviews pass and
  /// nothing conflicts.
  public let isReadyToMerge: Bool
  /// The branch it merges, by its name in the head repository.
  public let headBranch: String
  /// The head commit: the branch's last pushed one, or, once merged, the one
  /// it was merged at. What says whether a merge covers a local branch.
  public let headCommit: String
  /// The repository the head branch lives in, which is a fork's for a pull
  /// request from one.
  public let headRepository: RemoteRepository
  public let baseBranch: String
  public let updatedAt: Date
}
