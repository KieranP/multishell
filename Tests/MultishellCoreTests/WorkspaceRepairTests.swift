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

  @Test func aNameForAMissingWorktreeGoesAndABlankOneWithIt() {
    var (ws, _) = sound()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    ws.worktrees.append(other)
    ws.worktreeNames = [worktree.id: "Checkout", other.id: "  ", "/repos/nowhere": "Ghost"]

    ws.repairReferences()

    #expect(ws.worktreeNames == [worktree.id: "Checkout"])
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
      { $0.worktreeNames["/nowhere"] = "Ghost" },
      { $0.worktreeNames[$0.worktrees[0].id] = "  " },
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
      { $0.projects.append($0.projects[0]) },
      { $0.worktrees.append($0.worktrees[0]) },
      { ws in ws.sessions.append(ws.sessions[0]) },
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

/// Shapes the store never writes but a hand edit or a half-written save can:
/// one session shown in two places, and splits with too few children nested
/// where the top-level checks do not look. Each must come out satisfying
/// every invariant, since `SessionRegistry` would otherwise open a shell for
/// a pane that another pane already shows, or a view would divide by zero
/// laying out an empty split.
@Suite
struct WorkspaceRepairShapeTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
  private var worktree: Worktree {
    Worktree(path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
  }

  private func workspace(tabs: [TerminalTab], sessions: [TerminalSession]) -> Workspace {
    var ws = Workspace()
    ws.projects = [project]
    ws.worktrees = [worktree]
    ws.sessions = sessions
    ws.tabs = tabs
    if let last = tabs.last { ws.activeTabByWorktree[worktree.id] = last.id }
    return ws
  }

  private func session() -> TerminalSession {
    TerminalSession(worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
  }

  @Test func aSessionInTwoTabsStaysInTheFirstOnly() {
    let shared = session()
    let own = session()
    let first = TerminalTab(worktreeID: worktree.id, session: shared.id)
    let second = TerminalTab(
      worktreeID: worktree.id,
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
      worktreeID: worktree.id,
      root: .split(
        axis: .vertical, children: [.terminal(twice.id), .terminal(other.id), .terminal(twice.id)]),
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
      worktreeID: worktree.id,
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
      worktreeID: worktree.id,
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

  /// Random trees mixing every kind of damage at every depth. Whatever the
  /// input, repair must end with the invariants true and change nothing on a
  /// second pass.
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
          worktreeID: worktree.id, root: root,
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

/// The store never adds the same project or worktree twice, but a state
/// file can hold one twice: a hand edit, or two spellings of one path that
/// normalise to the same identity. Every view keys on identity, and the
/// New Worktree picker's labels are a dictionary that traps on a repeat.
@Suite
struct WorkspaceRepairDuplicateTests {
  @Test func aProjectListedTwiceKeepsItsFirstEntryAndItsWorktrees() throws {
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [
            { "path": "file:///repos/demo/", "settings": { "branchPrefix": "k/" } },
            { "path": "file:///repos/x/../demo", "isExpanded": false } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" },
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ] }
        """#.utf8))
    #expect(ws.projects.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate project")
    #expect(ws.projects.map(\.id) == ["/repos/demo"])
    #expect(ws.projects[0].settings.branchPrefix == "k/", "the first entry is the one kept")
    #expect(ws.worktrees.map(\.id) == ["/repos/demo"])
  }
}
