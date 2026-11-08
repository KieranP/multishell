import Foundation

extension URL {
  /// The kernel's MAXSYMLINKS: a longer chain is a loop.
  private static let maximumLinkHops = 32

  /// Where a write to this path lands. A link at the end of the path is written
  /// through, not over, so a dotfiles repo keeps seeing the file.
  var linkTarget: URL {
    var current = self
    // Followed link by link: `resolvingSymlinksInPath` hands back a link whose
    // target does not exist yet, and the write would replace it.
    for _ in 0..<Self.maximumLinkHops {
      guard let target = try? FileManager.default.destinationOfSymbolicLink(atPath: current.path)
      else { return current }
      let directory = current.deletingLastPathComponent().resolvingSymlinksInPath()
      current = URL(fileURLWithPath: target, relativeTo: directory).standardizedFileURL
    }
    return current
  }
}
