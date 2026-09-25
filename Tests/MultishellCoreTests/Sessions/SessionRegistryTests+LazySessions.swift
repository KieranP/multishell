import Foundation
import Testing

@testable import MultishellCore

extension SessionRegistryTests {
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
    let registry = SessionRegistry(store: store, host: host)
    var callbacks = 0
    registry.onLiveSessionsChanged = { callbacks += 1 }

    registry.reconcile(shouldBeLive: { $0.worktreeID == warm.id })

    #expect(registry.liveSessionIDs == [warmTab.focusedSessionID])
    #expect(callbacks == 1)

    registry.reconcile()
    #expect(registry.liveSessionIDs.count == 2)
  }

  @Test func aRetitleIsItsOwnCallbackNotActivity() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let tab = store.openTab(in: worktree.id)!
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    var seen: [TerminalSession.ID] = []
    var titled: [String] = []
    registry.onActivity = { seen.append($0) }
    registry.onRetitle = { titled.append($1) }

    host.delegate?.terminalHost(host, didRetitle: tab.focusedSessionID, to: "make")
    host.delegate?.terminalHost(host, didSeeActivityIn: tab.focusedSessionID)

    #expect(seen == [tab.focusedSessionID])
    #expect(titled == ["make"])
  }

  @Test func aFinishedCommandIsItsOwnCallbackNotActivity() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let tab = store.openTab(in: worktree.id)!
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    var activity: [TerminalSession.ID] = []
    var finished: [(TerminalSession.ID, Int32?)] = []
    registry.onActivity = { activity.append($0) }
    registry.onCommandFinished = { finished.append(($0, $1)) }

    host.delegate?.terminalHost(host, didFinishCommandIn: tab.focusedSessionID, exitCode: 2)

    #expect(finished.count == 1 && finished[0].0 == tab.focusedSessionID && finished[0].1 == 2)
    #expect(activity.isEmpty)
  }

  @Test func prepareDecidesWhatTheHostOpensWithoutTouchingTheStore() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let tab = store.openTab(in: worktree.id, title: "Claude Code", agentID: "claude")!
    let host = OpenRecordingHost()
    let registry = SessionRegistry(store: store, host: host)

    registry.reconcile(prepare: { session in
      var prepared = session
      prepared.command = ["/bin/zsh", "-l", "-c", "claude"]
      return prepared
    })

    #expect(host.opened.first?.command == ["/bin/zsh", "-l", "-c", "claude"])
    #expect(host.opened.first?.agentID == "claude")
    #expect(store.workspace.session(tab.focusedSessionID)?.command == nil, "the store keeps the id")
  }

  @Test func focusFromTheHostUpdatesTheStore() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    _ = registry

    host.delegate?.terminalHost(host, didFocus: first.focusedSessionID)

    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id != second.id)
  }
}

@MainActor
private final class OpenRecordingHost: TerminalHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var opened: [TerminalSession] = []
  weak var delegate: (any TerminalHostDelegate)?
  func open(_ session: TerminalSession) throws {
    openSessionIDs.insert(session.id)
    opened.append(session)
  }
  func close(_ id: TerminalSession.ID) { openSessionIDs.remove(id) }
  func focus(_ id: TerminalSession.ID) {}
  func paste(_ text: String, into id: TerminalSession.ID) -> Bool { true }
  func apply(_ theme: Theme, appearance: Appearance) {}
}
