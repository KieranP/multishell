import Foundation
import Testing

@testable import MultishellCore

/// State off disk can be inconsistent: a crash mid-save, a hand edit, a bug
/// in an earlier build. Each test breaks one invariant the store otherwise
/// maintains and checks that `repairReferences` restores it without losing
/// anything that was sound.
@Suite
struct WorkspaceRepairTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
  private var worktree: Worktree {
    Worktree(path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
  }

  private func session() -> TerminalSession {
    TerminalSession(worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
  }

  private func sound() -> (Workspace, TerminalTab) {
    var ws = Workspace()
    ws.projects = [project]
    ws.worktrees = [worktree]
    let s = session()
    let tab = TerminalTab(worktreeID: worktree.id, session: s.id)
    ws.sessions = [s]
    ws.tabs = [tab]
    ws.activeTabByWorktree[worktree.id] = tab.id
    ws.selectedWorktreeID = worktree.id
    return (ws, tab)
  }

  @Test func aSoundWorkspaceIsLeftAlone() {
    let (ws, _) = sound()
    var repaired = ws
    repaired.repairReferences()
    #expect(repaired == ws)
  }

  @Test func worktreesOfAMissingProjectGoWithTheirTabs() {
    var (ws, _) = sound()
    let stray = Worktree(
      path: URL(fileURLWithPath: "/repos/x"), projectID: "/repos/gone", head: "b")
    let straySession = TerminalSession(
      worktreeID: stray.id, workingDirectory: stray.path, title: "sh")
    ws.worktrees.append(stray)
    ws.sessions.append(straySession)
    ws.tabs.append(TerminalTab(worktreeID: stray.id, session: straySession.id))

    ws.repairReferences()

    #expect(ws.worktrees.map(\.id) == [worktree.id])
    #expect(ws.tabs.count == 1 && ws.sessions.count == 1)
  }

  @Test func aSessionNoTabOwnsIsDropped() {
    var (ws, tab) = sound()
    ws.sessions.append(session())

    ws.repairReferences()

    #expect(ws.sessions.map(\.id) == [tab.focusedSessionID])
  }

  @Test func aPaneWhoseSessionIsMissingCollapsesAndTheTabSurvives() {
    var (ws, tab) = sound()
    let ghost = UUID()
    var split = tab
    split.root = .split(
      axis: .horizontal, children: [.terminal(tab.focusedSessionID), .terminal(ghost)])
    split.focusedSessionID = ghost
    ws.tabs = [split]

    ws.repairReferences()

    #expect(ws.tabs[0].root == .terminal(tab.focusedSessionID))
    #expect(
      ws.tabs[0].focusedSessionID == tab.focusedSessionID, "focus cannot point outside the tree")
  }

  @Test func aTabWithNoLiveSessionsIsRemovedAndTheActiveEntryMovesOn() {
    var (ws, tab) = sound()
    let empty = TerminalTab(worktreeID: worktree.id, session: UUID())
    ws.tabs.append(empty)
    ws.activeTabByWorktree[worktree.id] = empty.id

    ws.repairReferences()

    #expect(ws.tabs.map(\.id) == [tab.id])
    #expect(ws.activeTabByWorktree[worktree.id] == tab.id, "otherwise the tab strip is hidden")
  }

  @Test func anActiveEntryForAnotherWorktreesTabIsCorrected() {
    var (ws, tab) = sound()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    ws.worktrees.append(other)
    ws.activeTabByWorktree[other.id] = tab.id

    ws.repairReferences()

    #expect(ws.activeTabByWorktree[other.id] == nil)
    #expect(ws.activeTabByWorktree[worktree.id] == tab.id)
  }

  @Test func aSelectionOfAMissingWorktreeIsCleared() {
    var (ws, _) = sound()
    ws.selectedWorktreeID = "/repos/nowhere"
    ws.repairReferences()
    #expect(ws.selectedWorktreeID == nil)
  }

  /// Random damage, then repair: the result must satisfy every invariant and
  /// a second repair must change nothing.
  @Test(arguments: [7, 11, 19, 23, 29, 31] as [UInt64])
  func repairIsCompleteAndIdempotentOnRandomDamage(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    var (ws, tab) = sound()
    let ghost = UUID()
    let damage: [(inout Workspace) -> Void] = [
      {
        $0.sessions.append(
          TerminalSession(
            worktreeID: "/nowhere", workingDirectory: URL(fileURLWithPath: "/n"), title: "x"))
      },
      { $0.tabs.append(TerminalTab(worktreeID: "/nowhere", session: ghost)) },
      { $0.activeTabByWorktree[$0.worktrees[0].id] = UUID() },
      { $0.activeTabByWorktree["/nowhere"] = tab.id },
      { $0.selectedWorktreeID = "/nowhere" },
      {
        $0.worktrees.append(
          Worktree(path: URL(fileURLWithPath: "/x"), projectID: "/gone", head: "h"))
      },
      { ws in
        var split = ws.tabs[0]
        split.root = .split(
          axis: .vertical, children: [.terminal(ghost), split.root], weights: [1])
        split.focusedSessionID = ghost
        ws.tabs[0] = split
      },
      {
        $0.tabs.append(
          TerminalTab(
            worktreeID: $0.worktrees[0].id, root: .split(axis: .horizontal, children: []),
            focusedSessionID: ghost))
      },
    ]
    for _ in 0..<Int.random(in: 1...6, using: &rng) {
      damage.randomElement(using: &rng)!(&ws)
    }

    ws.repairReferences()
    WorkspaceInvariants.check(ws, "seed \(seed)")
    var again = ws
    again.repairReferences()
    #expect(again == ws, "seed \(seed): repair is not idempotent")
    #expect(ws.projects.count == 1, "seed \(seed): repair must never drop a project")
  }

  @Test func aSplitWithNoPanesAtAllIsDropped() {
    var (ws, tab) = sound()
    var hollow = tab
    hollow.root = .split(axis: .vertical, children: [])
    ws.tabs = [hollow]

    ws.repairReferences()

    #expect(ws.tabs.isEmpty)
    #expect(ws.sessions.isEmpty)
    #expect(ws.activeTabByWorktree[worktree.id] == nil)
  }
}
