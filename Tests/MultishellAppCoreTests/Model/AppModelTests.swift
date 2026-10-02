import Foundation
import TestScratch
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelTests {
  @Test(arguments: [3, 4, 6, 9, 12, 17, 25, 33] as [UInt64])
  func anySequenceOfActionsAndEventsKeepsTheRuntimeConsistent(seed: UInt64) {
    var generator = SeededGenerator(seed: seed)
    let harness = Harness()
    let worktrees = [harness.main, harness.feature]

    for step in 0..<300 {
      let workspace = harness.model.workspace
      let live = Array(harness.engine.liveSessionIDs)
      switch Int.random(in: 0..<22, using: &generator) {
      case 0, 1: harness.model.select(worktrees.randomElement(using: &generator)!)
      case 2: harness.model.newTab()
      case 3: harness.model.closeActivePane()
      case 4: harness.model.closeActiveTab()
      case 5:
        harness.model.splitActivePane(Bool.random(using: &generator) ? .horizontal : .vertical)
      case 6:
        if let tab = workspace.tabs.randomElement(using: &generator) { harness.model.activate(tab) }
      case 7:
        Bool.random(using: &generator)
          ? harness.model.activateNextTab() : harness.model.activatePreviousTab()
      case 8:
        if let id = live.randomElement(using: &generator) {
          harness.engine.delegate?.terminalHost(harness.engine, didExit: id)
        }
      case 9:
        if let id = live.randomElement(using: &generator) {
          harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: id)
          harness.engine.delegate?.terminalHost(harness.engine, didRetitle: id, to: "t\(step)")
        }
      case 10:
        // A click lands only on a visible pane, and the click itself gives
        // the surface focus, which the fake records as if `focus` had.
        if let selected = workspace.selectedWorktreeID,
          let shown = workspace.activeTab(in: selected),
          let id = shown.sessionIDs.randomElement(using: &generator)
        {
          harness.engine.focused.append(id)
          harness.engine.delegate?.terminalHost(harness.engine, didFocus: id)
        }
      case 11, 12:
        // A report over the socket: about a live shell, a dead one, an
        // unknown one, or a directory only.
        let state = SessionState.allCases.randomElement(using: &generator)!
        let subject = Int.random(in: 0..<4, using: &generator)
        let session: TerminalSession.ID? =
          switch subject {
          case 0: live.randomElement(using: &generator)
          case 1: workspace.sessions.randomElement(using: &generator)?.id
          case 2: UUID()
          default: nil
          }
        let workingDirectory =
          Bool.random(using: &generator)
          ? worktrees.randomElement(using: &generator)!.path.path : "/x"
        // Some reports name an agent, as Claude's hooks do; an id this
        // build does not know is as likely as one it does.
        let agent = ["claude", "future-agent", nil].randomElement(using: &generator)!
        harness.stateSource.send(
          SessionStateReport(
            state: state, sessionID: session, workingDirectory: workingDirectory,
            pid: Bool.random(using: &generator)
              ? Int32.random(in: 1...99999, using: &generator) : nil,
            agentID: agent))
      case 13:
        if let id = live.randomElement(using: &generator) {
          harness.engine.delegate?.terminalHost(
            harness.engine, didFinishCommandIn: id,
            exitCode: Int32.random(in: 0...2, using: &generator))
        }
      case 14:
        if Bool.random(using: &generator), let tab = workspace.tabs.randomElement(using: &generator)
        {
          harness.model.clearState(of: tab)
        } else {
          harness.model.clearState(ofWorktree: worktrees.randomElement(using: &generator)!.id)
        }
      case 15:
        if let tab = workspace.tabs.randomElement(using: &generator) {
          harness.model.moveTab(tab.id, toWorktree: worktrees.randomElement(using: &generator)!.id)
        }
      case 16:
        harness.model.moveActiveTabToNewGroup()
      case 17:
        if let tab = workspace.tabs.randomElement(using: &generator),
          let group = workspace.tabGroups.randomElement(using: &generator)
        {
          harness.model.moveTab(
            tab.id, Bool.random(using: &generator) ? .before : .after, toNewGroupOf: group.id)
        }
      case 18:
        if let tab = workspace.tabs.randomElement(using: &generator),
          let group = workspace.tabGroups.randomElement(using: &generator)
        {
          harness.model.moveTab(tab.id, toEndOf: group.id)
        }
      case 19:
        Bool.random(using: &generator)
          ? harness.model.focusNextGroup() : harness.model.focusPreviousGroup()
      case 20:
        if let group = workspace.tabGroups.randomElement(using: &generator) {
          Bool.random(using: &generator)
            ? harness.model.newTab(in: group.id)
            : harness.model.setGroupWeights(
              (0..<Int.random(in: 1...3, using: &generator)).map { _ in
                Double.random(in: 0.1...3, using: &generator)
              }, in: group.worktreeID)
        }
      default:
        // A refresh that lost or found a worktree, then the reconcile every
        // model action ends with.
        let kept = worktrees.filter { _ in Bool.random(using: &generator) }
        harness.store.replaceWorktrees(
          kept.isEmpty ? worktrees : kept, forProject: harness.project.id)
        harness.model.reconcileSessions(takingFocus: true)
      }
      expectRuntimeConsistent(harness, "seed \(seed) step \(step)")
    }
  }

  private func expectRuntimeConsistent(_ harness: Harness, _ context: String) {
    let workspace = harness.model.workspace
    let live = harness.engine.liveSessionIDs
    let sessionIDs = Set(workspace.sessions.map(\.id))

    #expect(harness.model.liveSessionIDs == live, "\(context): views see a different live set")
    #expect(live.isSubset(of: sessionIDs), "\(context): a shell with no session")
    #expect(
      Set(harness.model.sessionTitles.keys).isSubset(of: live), "\(context): title of a dead shell")
    #expect(
      Set(harness.model.reportedAgents.keys).isSubset(of: live),
      "\(context): an agent reported in a dead shell")
    for key in harness.model.sessionStates.states.keys {
      switch key {
      case .session(let id): #expect(live.contains(id), "\(context): dot for a dead shell")
      case .worktree(let id):
        #expect(workspace.worktree(id) != nil, "\(context): state for a missing worktree")
      }
    }
    #expect(
      Set(harness.model.sessionStates.pids.keys).isSubset(
        of: Set(harness.model.sessionStates.states.keys)),
      "\(context): a pid with no state")
    if let selected = workspace.selectedWorktreeID {
      // Failed survives being looked at, as Waiting does, so the focused pane
      // may hold one. Nor is a Done on another pane in view: it waits for focus.
      #expect(
        harness.model.sessionStates[.worktree(selected)] != .done,
        "\(context): unseen Done shown")
      if let focused = workspace.activeTab(in: selected)?.focusedSessionID {
        #expect(
          harness.model.sessionStates[.session(focused)] != .done,
          "\(context): unseen Done in the focused pane")
      }
    }
    #expect(harness.model.liveTerminalCount == live.count, "\(context): quit guard count")

    for session in workspace.sessions {
      let warm = harness.model.warmWorktrees.contains(session.worktreeID)
      #expect(live.contains(session.id) == warm, "\(context): warmth and liveness disagree")
    }

    if let selected = workspace.selectedWorktreeID, let tab = workspace.activeTab(in: selected) {
      #expect(
        harness.engine.focused.last == tab.focusedSessionID,
        "\(context): engine focus is not the shown pane")
    }
    for tab in workspace.tabs {
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      #expect(tab.sessionIDs.allSatisfy(sessionIDs.contains), "\(context): pane without a session")
      #expect(
        workspace.group(tab.groupID)?.worktreeID == tab.worktreeID,
        "\(context): a tab in another worktree's group, or in none")
    }
    for group in workspace.tabGroups {
      #expect(!workspace.tabs(inGroup: group.id).isEmpty, "\(context): a group with no tabs")
      #expect(
        workspace.shownTab(in: group) != nil, "\(context): a group showing nothing")
      #expect(group.weight.isFinite && group.weight > 0, "\(context): a group with no width")
    }
  }
}
