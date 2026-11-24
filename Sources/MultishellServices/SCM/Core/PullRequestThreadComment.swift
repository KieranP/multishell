import Foundation

/// One comment of a review thread, as the host words it.
public struct PullRequestThreadComment: Hashable, Sendable {
  public let id: String
  /// The author's login; `nil` for a deleted account.
  public let author: String?
  /// As written, markdown and HTML both: what an agent is sent.
  public let body: String
  /// The body as the host renders it, its markup gone: what the page shows.
  public let bodyText: String
  public let url: URL?
}
