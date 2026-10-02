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
    host.liveSessionIDs.insert(orphan)

    let failures = reconciler.reconcile()

    #expect(failures.isEmpty)
    #expect(host.liveSessionIDs == Set(store.workspace.sessions.map(\.id)))
    #expect(host.log == ["close", "open"])
  }

  @Test func processExitClosesTheSurfaceAndFocusesTheNextTab() {
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!
    reconciler.reconcile()
    host.log.removeAll()

    host.delegate?.terminalHost(host, didExit: second.focusedSessionID)

    #expect(store.workspace.tabs.map(\.id) == [first.id])
    #expect(!host.liveSessionIDs.contains(second.focusedSessionID))
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

  @Test func aRetitleIsItsOwnCallbackNotActivity() {
    let tab = store.openTab(in: worktree.id)!
    var seen: [TerminalSession.ID] = []
    var titled: [String] = []
    reconciler.onActivity = { seen.append($0) }
    reconciler.onRetitle = { titled.append($1) }

    host.delegate?.terminalHost(host, didRetitle: tab.focusedSessionID, to: "make")
    host.delegate?.terminalHost(host, didSeeActivityIn: tab.focusedSessionID)

    #expect(seen == [tab.focusedSessionID])
    #expect(titled == ["make"])
  }

  @Test func aFinishedCommandIsItsOwnCallbackNotActivity() {
    let tab = store.openTab(in: worktree.id)!
    var activity: [TerminalSession.ID] = []
    var finished: [(TerminalSession.ID, Int32?)] = []
    reconciler.onActivity = { activity.append($0) }
    reconciler.onCommandFinished = { finished.append(($0, $1)) }

    host.delegate?.terminalHost(host, didFinishCommandIn: tab.focusedSessionID, exitCode: 2)

    #expect(finished.count == 1 && finished[0].0 == tab.focusedSessionID && finished[0].1 == 2)
    #expect(activity.isEmpty)
  }

  @Test func prepareDecidesWhatTheHostOpensWithoutTouchingTheStore() {
    let tab = store.openTab(in: worktree.id, title: "Claude Code", agentID: "claude")!

    reconciler.reconcile(prepare: { session in
      var prepared = session
      prepared.command = ["/bin/zsh", "-l", "-c", "claude"]
      return prepared
    })

    #expect(host.opened.first?.command == ["/bin/zsh", "-l", "-c", "claude"])
    #expect(host.opened.first?.agentID == "claude")
    #expect(store.workspace.session(tab.focusedSessionID)?.command == nil, "the store keeps the id")
  }
}
