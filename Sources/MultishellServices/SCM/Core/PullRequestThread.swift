import Foundation

/// An unresolved review thread on a pull request: a comment on its diff and the
/// replies under it. Runtime only, read while the PR page shows.
public struct PullRequestThread: Hashable, Sendable {
  public let id: String
  public let path: String
  /// Where it sits in the head's file; `nil` for a comment on the whole file
  /// or an outdated one, whose lines the head has moved past.
  public let line: Int?
  /// Where it sat when written, which an outdated thread is labelled by.
  public let originalLine: Int?
  public let isOutdated: Bool
  /// The diff its first comment was written on, ending at its line.
  public let diffHunk: String
  /// Oldest first; never empty, a thread being its first comment.
  public let comments: [PullRequestThreadComment]
}
