import MultishellCore

@testable import MultishellAppCore

extension Harness {
  /// Selects `main` and opens `path` in a file tab last in its focused group,
  /// over the shell tab selecting it opened.
  func openFileTab(_ path: String = "README.md") -> FileTab {
    model.select(main)
    let tab = store.openFileTab(path: path, in: main.id)!
    model.reconcileSessions(takingFocus: true)
    return tab
  }
}
