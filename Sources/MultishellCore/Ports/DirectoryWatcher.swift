import Foundation

/// Tells the core when a set of directories changes. A port so the tests can
/// fake it; implementations coalesce bursts.
@MainActor
public protocol DirectoryWatcher: AnyObject {
  /// The directories that fired since the last call, so the core can read
  /// only the project they belong to; empty where the watcher cannot say.
  var onChange: (@MainActor ([URL]) -> Void)? { get set }

  /// Replaces the watched set on return, unless a later call began meanwhile.
  /// A path not there yet is skipped; call again once it is.
  func watch(_ directories: [URL]) async
  func stop()
}
