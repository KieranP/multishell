import Foundation
import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func aSessionThatCannotOpenIsReportedAndLeftInTheStore() {
    let good = store.openTab(in: worktree.id)!
    let bad = store.openTab(in: worktree.id)!
    host.failing = [bad.focusedSessionID]

    let failures = reconciler.reconcile()

    #expect(failures.map(\.sessionID) == [bad.focusedSessionID])
    #expect((failures[0].error as NSError).code == 12)
    #expect(host.liveSessionIDs == [good.focusedSessionID])
    #expect(store.workspace.sessions.count == 2, "the caller decides whether to drop it")

    host.failing = []
    #expect(reconciler.reconcile().isEmpty)
    #expect(host.liveSessionIDs.count == 2)
  }
}
