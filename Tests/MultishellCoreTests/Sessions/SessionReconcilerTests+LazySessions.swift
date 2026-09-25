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

  @Test func focusFromTheHostUpdatesTheStore() {
    let first = store.openTab(in: worktree.id)!
    let second = store.openTab(in: worktree.id)!

    host.delegate?.terminalHost(host, didFocus: first.focusedSessionID)

    #expect(store.workspace.activeTab(in: worktree.id)?.id == first.id)
    #expect(store.workspace.activeTab(in: worktree.id)?.id != second.id)
  }
}
