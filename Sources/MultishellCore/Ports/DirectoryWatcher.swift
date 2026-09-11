import Foundation

/// Tells the core when a set of directories changes. No portable API, so
/// each platform supplies one; implementations coalesce bursts.
@MainActor
public protocol DirectoryWatcher: AnyObject {
  var onChange: (@MainActor () -> Void)? { get set }

  /// Replaces the watched set. Paths that do not exist yet are skipped;
  /// call again after they appear.
  func watch(_ directories: [URL])
  func stop()
}
