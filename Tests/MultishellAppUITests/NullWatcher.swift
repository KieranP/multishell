import AppKit
import MultishellCore

@MainActor
final class NullWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  func watch(_ directories: [URL]) {}
  func stop() {}
}
