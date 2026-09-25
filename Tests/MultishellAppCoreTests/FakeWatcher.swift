import Foundation
import MultishellCore

/// A watcher that records what it was asked to watch and can be poked.
@MainActor
final class FakeWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  var watched: [URL] = []
  func watch(_ directories: [URL]) { watched = directories }
  func stop() {}
}
