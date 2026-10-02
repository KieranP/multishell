import MultishellCore

@testable import MultishellAppCore

extension Harness {
  /// Selects `main` and opens a second tab over its first, which it returns:
  /// a tab whose panes report from out of view.
  func openBackgroundTab() -> TerminalTab {
    model.select(main)
    let first = model.workspace.activeTab(in: main.id)!
    model.newTab()
    return first
  }
}
