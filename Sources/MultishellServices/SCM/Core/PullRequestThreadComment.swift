import Foundation

/// One comment of a review thread, as the host words it.
public struct PullRequestThreadComment: Hashable, Sendable {
  public let id: String
  /// The author's login; `nil` for a deleted account.
  public let author: String?
  public let body: String
  public let url: URL?
}
