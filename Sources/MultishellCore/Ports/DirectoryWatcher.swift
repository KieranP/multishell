import Foundation

/// Tells the core when anything under a set of directories changes. A port so
/// the tests can fake it; implementations coalesce bursts.
@MainActor
public protocol DirectoryWatcher: AnyObject {
  /// What changed since the last call: the directory holding each change, or the
  /// entry at the top of a watched one; WatchedDirectories names those kept whole.
  var onChange: (@MainActor ([URL]) -> Void)? { get set }

  /// Replaces the watched set on return, unless a later call began meanwhile.
  /// A path not there yet is skipped; call again once it is.
  func watch(_ directories: [URL]) async
  func stop()
}
