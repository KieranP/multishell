import Foundation
import Testing

@testable import MultishellCore

extension SessionReconcilerTests {
  @Test func onlyLiveWorktreesGetShellsAndTheCallbackFires() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let warm = Worktree(
      path: URL(fileURLWithPath: "/repos/demo"), projectID: project.id, head: "a", branch: "main",
      isPrimary: true)
    let cold = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-feat"), projectID: project.id, head: "b",
      branch: "feat")
    store.replaceWorktrees([warm, cold], forProject: project.id)
    let warmTab = store.openTab(in: warm.id)!
    store.openTab(in: cold.id)

    let host = RecordingHost()
    let reconciler = SessionReconciler(store: store, host: host)
    var callbacks = 0
    reconciler.onLiveSessionsChanged = { callbacks += 1 }

    reconciler.reconcile(shouldBeLive: { $0.worktreeID == warm.id })

    #expect(reconciler.liveSessionIDs == [warmTab.focusedSessionID])
    #expect(callbacks == 1)

    reconciler.reconcile()
    #expect(reconciler.liveSessionIDs.count == 2)
  }
}
