import Foundation

/// Tells the core when a set of directories changes.
///
/// File watching has no portable API (kqueue on Darwin, inotify on Linux),
/// so each platform supplies one. Implementations coalesce bursts; the core
/// only wants "look again".
@MainActor
public protocol DirectoryWatcher: AnyObject {
  var onChange: (@MainActor () -> Void)? { get set }

  /// Replaces the watched set. Paths that do not exist yet are skipped;
  /// call again after they appear.
  func watch(_ directories: [URL])
  func stop()
}
