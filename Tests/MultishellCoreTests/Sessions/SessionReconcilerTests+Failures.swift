import Foundation
import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func aSessionThatCannotOpenIsReportedAndLeftInTheStore() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let good = store.openTab(in: worktree.id)!
    let bad = store.openTab(in: worktree.id)!
    let host = RecordingHost()
    host.failing = [bad.focusedSessionID]
    let reconciler = SessionReconciler(store: store, host: host)

    let failures = reconciler.reconcile()

    #expect(failures.map(\.sessionID) == [bad.focusedSessionID])
    #expect((failures[0].error as NSError).code == 12)
    #expect(host.openSessionIDs == [good.focusedSessionID])
    #expect(store.workspace.sessions.count == 2, "the caller decides whether to drop it")

    // Once the host can open it, the next reconcile picks it up.
    host.failing = []
    #expect(reconciler.reconcile().isEmpty)
    #expect(host.openSessionIDs.count == 2)
  }
}
