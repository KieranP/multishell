import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// Left unrepaired, `SessionRegistry` opens a second shell for a pane already shown, or a view
/// divides by zero laying out an empty split.
extension WorkspaceRepairTests {
  private func workspace(tabs: [TerminalTab], sessions: [TerminalSession]) -> Workspace {
    var ws = Workspace()
    ws.projects = [project]
    ws.worktrees = [worktree]
    ws.sessions = sessions
    ws.tabs = tabs
    // The tabs name no column, the shape of every state file written before columns existed.
    return ws
  }

  @Test func aSessionInTwoTabsStaysInTheFirstOnly() {
    let shared = session()
    let own = session()
    let first = TerminalTab(
      worktreeID: worktree.id, groupID: TabGroup.unassigned, session: shared.id)
    let second = TerminalTab(
      worktreeID: worktree.id, groupID: TabGroup.unassigned,
      root: .split(axis: .horizontal, children: [.terminal(own.id), .terminal(shared.id)]),
      focusedSessionID: shared.id)
    var ws = workspace(tabs: [first, second], sessions: [shared, own])

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "shared session")
    #expect(ws.tabs.map(\.root) == [.terminal(shared.id), .terminal(own.id)])
    #expect(ws.tabs[1].focusedSessionID == own.id)
  }

  @Test func aSessionTwiceInOneTreeKeepsItsFirstPane() {
    let twice = session()
    let other = session()
    let tab = TerminalTab(
      worktreeID: worktree.id, groupID: TabGroup.unassigned,
      root: .split(
        axis: .vertical,
        children: [.terminal(twice.id), .terminal(other.id), .terminal(twice.id)]),
      focusedSessionID: twice.id)
    var ws = workspace(tabs: [tab], sessions: [twice, other])

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate pane")
    #expect(ws.tabs[0].root.sessionIDs == [twice.id, other.id])
    #expect(ws.sessions.count == 2)
  }

  @Test func aNestedSplitWithNoChildrenIsRemovedAndTheTabKept() {
    let s = session()
    let tab = TerminalTab(
      worktreeID: worktree.id, groupID: TabGroup.unassigned,
      root: .split(
        axis: .horizontal, children: [.terminal(s.id), .split(axis: .vertical, children: [])]),
      focusedSessionID: s.id)
    var ws = workspace(tabs: [tab], sessions: [s])

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "empty nested split")
    #expect(ws.tabs[0].root == .terminal(s.id))
  }

  @Test func aNestedSplitWithOneChildCollapsesIntoIt() {
    let a = session()
    let b = session()
    let tab = TerminalTab(
      worktreeID: worktree.id, groupID: TabGroup.unassigned,
      root: .split(
        axis: .horizontal,
        children: [.terminal(a.id), .split(axis: .vertical, children: [.terminal(b.id)])],
        weights: [3, 1]),
      focusedSessionID: b.id)
    var ws = workspace(tabs: [tab], sessions: [a, b])

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "single-child nested split")
    #expect(
      ws.tabs[0].root
        == .split(
          axis: .horizontal, children: [.terminal(a.id), .terminal(b.id)], weights: [3, 1]))
  }

  @Test(arguments: [41, 43, 47, 53, 59, 61, 67, 71] as [UInt64])
  func randomTreesRepairCompletelyAndIdempotently(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    let pool = (0..<6).map { _ in session() }
    let ghost = UUID()

    func tree(depth: Int) -> PaneNode {
      if depth == 0 || Int.random(in: 0..<3, using: &rng) == 0 {
        return .terminal(Bool.random(using: &rng) ? ghost : pool.randomElement(using: &rng)!.id)
      }
      let count = Int.random(in: 0...3, using: &rng)
      let children = (0..<count).map { _ in tree(depth: depth - 1) }
      let weights =
        Bool.random(using: &rng)
        ? Array(repeating: 1.0, count: count) : [Double](repeating: 2, count: max(count - 1, 0))
      return .split(
        axis: Bool.random(using: &rng) ? .horizontal : .vertical, children: children,
        weights: weights)
    }

    var tabs: [TerminalTab] = []
    for _ in 0..<Int.random(in: 1...4, using: &rng) {
      let root = tree(depth: 3)
      tabs.append(
        TerminalTab(
          worktreeID: worktree.id, groupID: TabGroup.unassigned, root: root,
          focusedSessionID: root.sessionIDs.randomElement(using: &rng) ?? ghost))
    }
    var ws = workspace(tabs: tabs, sessions: pool)

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "seed \(seed)")
    var again = ws
    again.repairReferences()
    #expect(again == ws, "seed \(seed): repair is not idempotent")
  }
}
