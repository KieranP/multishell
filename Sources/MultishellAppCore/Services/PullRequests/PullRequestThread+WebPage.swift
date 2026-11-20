import Foundation
import MultishellServices

extension PullRequestThread {
  /// Its first comment's page where the host gave a web link.
  public var webPage: URL? { comments.first?.url?.asWebPage }
}
