import Foundation

extension URL {
  /// The `.app` holding this once its links are followed, `nil` outside one.
  public var enclosingAppBundle: URL? {
    var directory = resolvingSymlinksInPath()
    // Bounded on component count: at the root `deletingLastPathComponent`
    // appends `..` rather than standing still, so the obvious loop hangs.
    while directory.pathComponents.count > 1 {
      if directory.pathExtension == "app" { return directory }
      directory = directory.deletingLastPathComponent()
    }
    return nil
  }
}
