import Foundation
import Testing

@testable import MultishellCore

@Suite @MainActor
struct SessionReconcilerTests {
  let store: WorkspaceStore
  let host = RecordingHost()
  let reconciler: SessionReconciler
  let worktree: Worktree

  init() {
    store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    worktree = Worktree(
      path: project.path, projectID: project.id, head: "abc", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    store.selectWorktree(worktree.id)
    reconciler = SessionReconciler(store: store, host: host)
  }

  @Test func reconcileOpensWantedAndClosesOrphanedSessions() {
    store.openTab(in: worktree.id)
    let orphan = UUID()
    host.openSessionIDs.insert(orphan)

    let failures = reconciler.reconcile()

    #expect(failures.isEmpty)
    #expect(host.openSessionIDs == Set(store.workspace.sessions.map(\.id)))
    #expect(host.log == ["close", "open"])
  }

  @Test func processExitClosesTheSurfaceAndFocusesTheNextTab() {
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    reconciler.reconcile()
    host.log.removeAll()

    host.delegate?.terminalHost(host, didExit: second.focusedSessionID)

    #expect(store.workspace.tabs.map(\.id) == [first.id])
    #expect(!host.openSessionIDs.contains(second.focusedSessionID))
    #expect(host.log == ["close", "focus \(first.focusedSessionID.uuidString.prefix(4))"])
  }

  @Test func retitleReachesTheCallbackAndLeavesTheWorkspaceAlone() {
    let tab = store.openTab(in: worktree.id)!
    reconciler.reconcile()
    let before = store.workspace
    var titles: [(TerminalSession.ID, String)] = []
    reconciler.onRetitle = { titles.append(($0, $1)) }

    host.delegate?.terminalHost(host, didRetitle: tab.focusedSessionID, to: "vim")

    #expect(titles.count == 1 && titles[0].0 == tab.focusedSessionID && titles[0].1 == "vim")
    #expect(store.workspace == before, "a prompt must not schedule a save or re-render the world")
  }
}
