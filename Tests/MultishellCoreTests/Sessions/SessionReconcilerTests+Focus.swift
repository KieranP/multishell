import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func withNoWorktreeSelectedFocusingTheActiveSessionAsksTheHostNothing() {
    store.openTab(in: worktree.id)
    store.selectWorktree(nil)

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
