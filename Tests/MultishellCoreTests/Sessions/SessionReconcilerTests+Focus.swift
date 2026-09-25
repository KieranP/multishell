import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func focusActiveSessionDoesNothingWithoutASelection() {
    let store = WorkspaceStore()
    let host = RecordingHost()
    let reconciler = SessionReconciler(store: store, host: host)
    reconciler.focusActiveSession()
    #expect(host.log.isEmpty)
  }
}
