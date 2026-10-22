import MultishellCore

@testable import MultishellAppCore

extension Harness {
  /// In `main`, over the shell tab selecting it opened.
  func openFileTab(_ path: String = "README.md") -> FileTab {
    model.openFileTab(path, in: main)!
  }
}
