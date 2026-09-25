import Testing

@testable import MultishellCore

extension SessionRegistryTests {
  @Test func focusActiveSessionDoesNothingWithoutASelection() {
    let store = WorkspaceStore()
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    registry.focusActiveSession()
    #expect(host.log.isEmpty)
  }
}
