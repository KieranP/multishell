import Foundation
import MultishellCore

/// Which paths in a file drag are the user's own and which are copies macOS
/// made for the drop, asked for again through its promise; see terminals.md.
public enum DraggedFilePaths {
  /// Whether a dragged path is a copy macOS made for this drop, read off the
  /// `TemporaryItems` and `NSIRD_` marks it carries.
  static func isTemporaryCopy(_ url: URL) -> Bool {
    if url.standardizedFileURL.pathComponents.contains(where: { $0.hasPrefix("NSIRD_") }) {
      return true
    }
    let temporary = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    guard let below = url.pathComponents(under: temporary), !below.isEmpty else { return false }
    return below.dropLast().contains("TemporaryItems")
  }

  /// Whether a drag's own paths are enough, or its promise must be asked
  /// too. Anything carrying a copy needs the promise.
  public static func needsPromise(for urls: [URL]) -> Bool {
    urls.isEmpty || urls.contains { isTemporaryCopy($0) }
  }

  /// The files in a drag that are the user's originals and keep their path.
  /// The rest are copies, asked for again through the promise.
  public static func originals(among urls: [URL]) -> [URL] {
    urls.filter { !isTemporaryCopy($0) }
  }
}
