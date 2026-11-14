import AppKit
import MultishellAppCore

/// The file a Changes click scrolled to, reported as the one at the top while
/// the scroll stays where the reveal left it: a file near the end cannot reach
/// the top, and the row clicked would otherwise not light.
struct AllChangesRevealPin {
  let path: String
  /// Where the reveal's scroll landed, `nil` while it is landing.
  var origin: NSPoint?

  /// The pinned file where the scroll has not moved since, else `nil`.
  func topFile(at origin: NSPoint) -> AllChangesTopFile? {
    guard self.origin == nil || self.origin == origin else { return nil }
    return AllChangesTopFile(path: path, isHeaderScrolledPast: false)
  }
}
