import Foundation
import Testing

@testable import MultishellCore

/// Records what the registry asks of a host, in order.
@MainActor
private final class RecordingHost: TerminalHost {
  var openSessionIDs: Set<TerminalSession.ID> = []
  var log: [String] = []
  weak var delegate: (any TerminalHostDelegate)?

  func open(_ session: TerminalSession) throws {
    openSessionIDs.insert(session.id)
    log.append("open")
  }

  func close(_ id: TerminalSession.ID) {
    openSessionIDs.remove(id)
    log.append("close")
  }

  func focus(_ id: TerminalSession.ID) {
    log.append("focus \(id.uuidString.prefix(4))")
  }

  func paste(_ text: String, into id: TerminalSession.ID) -> Bool {
    log.append("paste \(text)")
    return true
  }

  func apply(_ theme: Theme, appearance: Appearance) {}
}

@Suite @MainActor
struct SessionRegistryTests {
  private let store: WorkspaceStore
  private let host = RecordingHost()
  private let registry: SessionRegistry
  private let worktree: Worktree

  init() {
    store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    worktree = Worktree(
      path: project.path, projectID: project.id, head: "abc", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    store.selectWorktree(worktree.id)
    registry = SessionRegistry(store: store, host: host)
  }

  @Test func reconcileOpensWantedAndClosesOrphanedSessions() {
    store.openTab(in: worktree.id)
    let orphan = UUID()
    host.openSessionIDs.insert(orphan)

    let failures = registry.reconcile()

    #expect(failures.isEmpty)
    #expect(host.openSessionIDs == Set(store.workspace.sessions.map(\.id)))
    #expect(host.log == ["close", "open"])
  }

  @Test func processExitClosesTheSurfaceAndFocusesTheNextTab() {
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    registry.reconcile()
    host.log.removeAll()

    host.delegate?.terminalHost(host, didExit: second.focusedSessionID, code: 0)

    #expect(store.workspace.tabs.map(\.id) == [first.id])
    #expect(!host.openSessionIDs.contains(second.focusedSessionID))
    #expect(host.log == ["close", "focus \(first.focusedSessionID.uuidString.prefix(4))"])
  }

  @Test func retitleReachesTheCallbackAndLeavesTheWorkspaceAlone() {
    let tab = store.openTab(in: worktree.id)!
    registry.reconcile()
    let before = store.workspace
    var titles: [(TerminalSession.ID, String)] = []
    registry.onRetitle = { titles.append(($0, $1)) }

    host.delegate?.terminalHost(host, didRetitle: tab.focusedSessionID, to: "vim")

    #expect(titles.count == 1 && titles[0].0 == tab.focusedSessionID && titles[0].1 == "vim")
    #expect(store.workspace == before, "a prompt must not schedule a save or re-render the world")
  }
}

@Suite @MainActor
struct LazySessionTests {
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

  @Test func retitleCountsAsActivity() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktree = Worktree(
      path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
    store.replaceWorktrees([worktree], forProject: project.id)
    let tab = store.openTab(in: worktree.id)!
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    var seen: [TerminalSession.ID] = []
    registry.onActivity = { seen.append($0) }

    host.delegate?.terminalHost(host, didRetitle: tab.focusedSessionID, to: "make")
    host.delegate?.terminalHost(host, didSeeActivityIn: tab.focusedSessionID)

    #expect(seen == [tab.focusedSessionID, tab.focusedSessionID])
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

    #expect(store.workspace.activeTabByWorktree[worktree.id] == first.id)
    #expect(store.workspace.activeTabByWorktree[worktree.id] != second.id)
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

@Suite @MainActor
struct SessionRegistryFailureTests {
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

@Suite @MainActor
struct SessionRegistryFocusTests {
  @Test func focusActiveSessionDoesNothingWithoutASelection() {
    let store = WorkspaceStore()
    let host = RecordingHost()
    let registry = SessionRegistry(store: store, host: host)
    registry.focusActiveSession()
    #expect(host.log.isEmpty)
  }
}
