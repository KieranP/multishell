import Foundation
import Testing

@testable import MultishellCore

@MainActor
private final class FailingHost: TerminalHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var failing: Set<TerminalSession.ID> = []
  weak var delegate: (any TerminalHostDelegate)?

  func open(_ session: TerminalSession) throws {
    if failing.contains(session.id) { throw NSError(domain: "pty", code: 12) }
    openSessionIDs.insert(session.id)
  }
  func close(_ id: TerminalSession.ID) { openSessionIDs.remove(id) }
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { true }
  func apply(_ theme: Theme, appearance: Appearance) {}
}

extension SessionRegistryTests {
  @Test func aSessionThatCannotOpenIsReportedAndLeftInTheStore() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let good = store.openTab(in: worktree.id)!
    let bad = store.openTab(in: worktree.id)!
    let host = FailingHost()
    host.failing = [bad.focusedSessionID]
    let registry = SessionRegistry(store: store, host: host)

    let failures = registry.reconcile()

    #expect(failures.map(\.sessionID) == [bad.focusedSessionID])
    #expect((failures[0].error as NSError).code == 12)
    #expect(host.openSessionIDs == [good.focusedSessionID])
    #expect(store.workspace.sessions.count == 2, "the caller decides whether to drop it")

    // Once the host can open it, the next reconcile picks it up.
    host.failing = []
    #expect(registry.reconcile().isEmpty)
    #expect(host.openSessionIDs.count == 2)
  }
}
