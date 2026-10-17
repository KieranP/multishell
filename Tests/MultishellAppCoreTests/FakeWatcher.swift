import Foundation
import MultishellCore

/// A watcher that records what it was asked to watch and can be poked.
@MainActor
final class FakeWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  var watched: [URL] = []
  /// Every set it was asked to watch, in order.
  private(set) var calls: [[URL]] = []
  /// Runs as each set is handed over, for a test to look at the disk then.
  var onWatch: (([URL]) -> Void)?
  func watch(_ directories: [URL]) {
    watched = directories
    calls.append(directories)
    onWatch?(directories)
  }
  func stop() {}
}
