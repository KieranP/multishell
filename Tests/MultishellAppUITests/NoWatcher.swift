import AppKit
import MultishellCore

@MainActor
final class NoWatcher: DirectoryWatcher {
  var onChange: (@MainActor ([URL]) -> Void)?
  func watch(_ directories: [URL]) {}
  func stop() {}
}
