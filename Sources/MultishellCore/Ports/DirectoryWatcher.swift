import Foundation

/// Tells the core when a set of directories changes. No portable API, so
/// each platform supplies one; implementations coalesce bursts.
@MainActor
public protocol DirectoryWatcher: AnyObject {
  /// The directories that fired since the last call, so the core can read
  /// only the project they belong to; empty where the watcher cannot say.
  var onChange: (@MainActor ([URL]) -> Void)? { get set }

  /// Replaces the watched set. Paths that do not exist yet are skipped;
  /// call again after they appear.
  func watch(_ directories: [URL])
  func stop()
}
