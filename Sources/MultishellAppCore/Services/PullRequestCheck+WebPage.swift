import Foundation
import MultishellServices

extension PullRequestCheck {
  /// The check's own page where its host gave a web link; any other scheme is
  /// never opened, and its row is no button.
  public var webPage: URL? {
    guard let link, ["http", "https"].contains(link.scheme?.lowercased()) else { return nil }
    return link
  }
}
