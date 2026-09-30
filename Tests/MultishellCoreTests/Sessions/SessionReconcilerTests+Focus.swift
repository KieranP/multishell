import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func withNoWorktreeSelectedFocusingTheActiveSessionAsksTheHostNothing() {
    let store = WorkspaceStore()
    let host = RecordingHost()
    let reconciler = SessionReconciler(store: store, host: host)
    reconciler.focusActiveSession()
    #expect(host.log.isEmpty)
  }

  @Test func focusFromTheHostUpdatesTheStore() {
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!

    host.delegate?.terminalHost(host, didFocus: first.focusedSessionID)

    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id != second.id)
  }
}
