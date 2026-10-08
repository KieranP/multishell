import MultishellCore

@testable import MultishellAppCore

extension Harness {
  /// A harness with `main` selected, and the one pane its first tab opens.
  static func withOnePane() -> (Harness, TerminalSession) {
    let harness = Harness()
    harness.model.select(harness.main)
    let session = harness.store.workspace.sessions[0]
    return (harness, session)
  }
}
