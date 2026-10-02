import MultishellCore

@testable import MultishellAppCore

@MainActor
func harnessWithOnePane() -> (Harness, TerminalSession) {
  let harness = Harness()
  harness.model.select(harness.main)
  let session = harness.store.workspace.sessions[0]
  return (harness, session)
}
