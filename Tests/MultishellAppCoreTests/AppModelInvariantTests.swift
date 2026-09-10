import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

/// Deterministic, so a failing sequence can be replayed from its seed.
private struct SeededGenerator: RandomNumberGenerator {
  private var state: UInt64
  init(seed: UInt64) { state = seed == 0 ? 0x9E37_79B9_7F4A_7C15 : seed }
  mutating func next() -> UInt64 {
    state ^= state << 13
    state ^= state >> 7
    state ^= state << 17
    return state
  }
}

/// Random user actions and engine events, in any order. After each, what the
/// views read must agree with what the engine has: the same live set, every
/// live shell backed by a session, no title or dot for a shell that is gone,
/// and the focused pane of the shown tab is what the engine was told to
/// focus last.
@Suite @MainActor
struct AppModelInvariantTests {
  @Test(arguments: [3, 4, 6, 9, 12, 17, 25, 33] as [UInt64])
  func anySequenceOfActionsAndEventsKeepsTheRuntimeConsistent(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    let h = Harness()
    let worktrees = [h.main, h.feature]

    for step in 0..<300 {
      let ws = h.model.workspace
      let live = Array(h.engine.openSessionIDs)
      switch Int.random(in: 0..<22, using: &rng) {
      case 0, 1: h.model.select(worktrees.randomElement(using: &rng)!)
      case 2: h.model.newTab()
      case 3: h.model.closeActivePane()
      case 4: h.model.closeActiveTab()
      case 5: h.model.splitActivePane(Bool.random(using: &rng) ? .horizontal : .vertical)
      case 6: if let tab = ws.tabs.randomElement(using: &rng) { h.model.activate(tab) }
      case 7: Bool.random(using: &rng) ? h.model.selectNextTab() : h.model.selectPreviousTab()
      case 8:
        if let id = live.randomElement(using: &rng) {
          h.engine.delegate?.terminalHost(h.engine, didExit: id, code: 0)
        }
      case 9:
        if let id = live.randomElement(using: &rng) {
          h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: id)
          h.engine.delegate?.terminalHost(h.engine, didRetitle: id, to: "t\(step)")
        }
      case 10:
        // A click lands only on a visible pane, and the click itself gives
        // the surface focus, which the fake records as if `focus` had.
        if let selected = ws.selectedWorktreeID, let shown = ws.activeTab(in: selected),
          let id = shown.sessionIDs.randomElement(using: &rng)
        {
          h.engine.focused.append(id)
          h.engine.delegate?.terminalHost(h.engine, didFocus: id)
        }
      case 11, 12:
        // A report over the socket: about a live shell, a dead one, an
        // unknown one, or a directory only.
        let state = SessionState.allCases.randomElement(using: &rng)!
        let subject = Int.random(in: 0..<4, using: &rng)
        let session: TerminalSession.ID? =
          switch subject {
          case 0: live.randomElement(using: &rng)
          case 1: ws.sessions.randomElement(using: &rng)?.id
          case 2: UUID()
          default: nil
          }
        let cwd = Bool.random(using: &rng) ? worktrees.randomElement(using: &rng)!.path.path : "/x"
        // Some reports name an agent, as Claude's hooks do; an id this
        // build does not know is as likely as one it does.
        let agent = ["claude", "future-agent", nil].randomElement(using: &rng)!
        h.source.send(
          SessionStateReport(
            state: state, sessionID: session, cwd: cwd,
            pid: Bool.random(using: &rng) ? Int32.random(in: 1...99999, using: &rng) : nil,
            agent: agent))
      case 13:
        if let id = live.randomElement(using: &rng) {
          h.engine.delegate?.terminalHost(
            h.engine, didFinishCommandIn: id, exitCode: Int32.random(in: 0...2, using: &rng))
        }
      case 14:
        if Bool.random(using: &rng), let tab = ws.tabs.randomElement(using: &rng) {
          h.model.clearState(of: tab)
        } else {
          h.model.clearState(ofWorktree: worktrees.randomElement(using: &rng)!.id)
        }
      case 15:
        // A tab dragged onto another worktree's row in the sidebar.
        if let tab = ws.tabs.randomElement(using: &rng) {
          h.model.moveTab(tab.id, to: worktrees.randomElement(using: &rng)!.id)
        }
      case 16:
        // Move Tab to New Group, from the menu.
        h.model.moveActiveTabToNewGroup()
      case 17:
        // A tab dragged to the band down one edge of a column.
        if let tab = ws.tabs.randomElement(using: &rng),
          let group = ws.tabGroups.randomElement(using: &rng)
        {
          h.model.moveTab(
            tab.id, Bool.random(using: &rng) ? .before : .after, toNewGroupOf: group.id)
        }
      case 18:
        // A tab dropped on another column's strip, clear of its tabs.
        if let tab = ws.tabs.randomElement(using: &rng),
          let group = ws.tabGroups.randomElement(using: &rng)
        {
          h.model.moveTab(tab.id, toEndOf: group.id)
        }
      case 19:
        Bool.random(using: &rng) ? h.model.focusNextGroup() : h.model.focusPreviousGroup()
      case 20:
        // The New Tab button of one column, and the divider drag beside it.
        if let group = ws.tabGroups.randomElement(using: &rng) {
          Bool.random(using: &rng)
            ? h.model.newTab(in: group.id)
            : h.model.setGroupWeights(
              (0..<Int.random(in: 1...3, using: &rng)).map { _ in
                Double.random(in: 0.1...3, using: &rng)
              }, in: group.worktreeID)
        }
      default:
        // A refresh that lost or found a worktree, then the sync every
        // model action ends with.
        let kept = worktrees.filter { _ in Bool.random(using: &rng) }
        h.store.replaceWorktrees(kept.isEmpty ? worktrees : kept, forProject: h.project.id)
        h.model.sync()
      }
      check(h, "seed \(seed) step \(step)")
    }
  }

  private func check(_ h: Harness, _ context: String) {
    let ws = h.model.workspace
    let live = h.engine.openSessionIDs
    let sessionIDs = Set(ws.sessions.map(\.id))

    #expect(h.model.liveSessions == live, "\(context): views see a different live set")
    #expect(live.isSubset(of: sessionIDs), "\(context): a shell with no session")
    #expect(Set(h.model.sessionTitles.keys).isSubset(of: live), "\(context): title of a dead shell")
    #expect(
      Set(h.model.reportedAgents.keys).isSubset(of: live),
      "\(context): an agent reported in a dead shell")
    for key in h.model.sessionStates.states.keys {
      switch key {
      case .session(let id): #expect(live.contains(id), "\(context): dot for a dead shell")
      case .worktree(let id):
        #expect(ws.worktree(id) != nil, "\(context): state for a missing worktree")
      }
    }
    #expect(
      Set(h.model.sessionStates.pids.keys).isSubset(of: Set(h.model.sessionStates.states.keys)),
      "\(context): a pid with no state")
    if let selected = ws.selectedWorktreeID {
      #expect(
        h.model.sessionStates[.worktree(selected)]?.isFinished != true,
        "\(context): unseen Done or Failed shown")
      for id in ws.shownTabs(in: selected).flatMap(\.sessionIDs) {
        #expect(
          h.model.sessionStates[.session(id)]?.isFinished != true,
          "\(context): unseen Done or Failed shown")
      }
    }
    #expect(h.model.liveTerminalCount == live.count, "\(context): quit guard count")

    // Every session of a visited worktree has a shell; unvisited ones none.
    for session in ws.sessions {
      let warm = h.model.warmWorktrees.contains(session.worktreeID)
      #expect(live.contains(session.id) == warm, "\(context): warmth and liveness disagree")
    }

    if let selected = ws.selectedWorktreeID, let tab = ws.activeTab(in: selected) {
      #expect(
        h.engine.focused.last == tab.focusedSessionID,
        "\(context): engine focus is not the shown pane")
    }
    for tab in ws.tabs {
      #expect(tab.root.contains(tab.focusedSessionID), "\(context): focus outside its tree")
      #expect(tab.sessionIDs.allSatisfy(sessionIDs.contains), "\(context): pane without a session")
      #expect(
        ws.group(tab.groupID)?.worktreeID == tab.worktreeID,
        "\(context): a tab in another worktree's column, or in none")
    }
    for group in ws.tabGroups {
      #expect(!ws.tabs(in: group.id).isEmpty, "\(context): a column with no tabs")
      #expect(
        ws.activeTab(in: group) != nil, "\(context): a column showing nothing")
      #expect(group.weight.isFinite && group.weight > 0, "\(context): a column with no width")
    }
  }
}
