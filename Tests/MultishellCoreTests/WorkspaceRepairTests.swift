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
    var group = TabGroup(worktreeID: worktree.id)
    let tab = TerminalTab(worktreeID: worktree.id, groupID: group.id, session: s.id)
    group.activeTabID = tab.id
    ws.sessions = [s]
    ws.tabs = [tab]
    ws.tabGroups = [group]
    ws.focusedGroupByWorktree[worktree.id] = group.id
    ws.selectedWorktreeID = worktree.id
    return (ws, tab)
  }

  /// The one column a sound single-column workspace has.
  private func onlyGroup(_ ws: Workspace) -> TabGroup { ws.tabGroups[0] }

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
    let strayGroup = TabGroup(worktreeID: stray.id)
    ws.worktrees.append(stray)
    ws.sessions.append(straySession)
    ws.tabGroups.append(strayGroup)
    ws.tabs.append(
      TerminalTab(worktreeID: stray.id, groupID: strayGroup.id, session: straySession.id))

    ws.repairReferences()

    #expect(ws.worktrees.map(\.id) == [worktree.id])
    #expect(ws.tabs.count == 1 && ws.sessions.count == 1)
    #expect(ws.tabGroups.count == 1, "the column went with the worktree")
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
    let empty = TerminalTab(
      worktreeID: worktree.id, groupID: onlyGroup(ws).id, session: UUID())
    ws.tabs.append(empty)
    ws.tabGroups[0].activeTabID = empty.id

    ws.repairReferences()

    #expect(ws.tabs.map(\.id) == [tab.id])
    #expect(
      ws.tabGroups[0].activeTabID == tab.id, "otherwise the column shows nothing")
  }

  @Test func anActiveEntryForAnotherWorktreesTabIsCorrected() {
    var (ws, tab) = sound()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    ws.worktrees.append(other)
    ws.focusedGroupByWorktree[other.id] = onlyGroup(ws).id

    ws.repairReferences()

    #expect(ws.focusedGroupByWorktree[other.id] == nil)
    #expect(ws.focusedGroupByWorktree[worktree.id] == onlyGroup(ws).id)
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id)
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

  /// The store writes a session's worktree with its tab's, so a file where
  /// they disagree was written by something else. The tab is what the
  /// sidebar lists it under, so the tab decides.
  @Test func aSessionSaidToBeInAnotherWorktreeThanItsTabIsPutBack() {
    var (ws, tab) = sound()
    ws.sessions[0].worktreeID = "/repos/nowhere"

    ws.repairReferences()

    #expect(ws.sessions.count == 1, "the session is the tab's, not a stray")
    #expect(ws.sessions[0].worktreeID == ws.tab(tab.id)?.worktreeID)
    #expect(
      ws.sessions[0].workingDirectory == worktree.path,
      "the directory it starts in comes back with it")
  }

  /// Every tab of a state file written before columns existed names no
  /// group. They belong in the one column they were saved as, not in one
  /// column each.
  @Test func tabsThatNameNoColumnAreGatheredIntoOne() {
    var (ws, tab) = sound()
    let second = session()
    ws.sessions.append(second)
    ws.tabs.append(
      TerminalTab(worktreeID: worktree.id, groupID: TabGroup.unassigned, session: second.id))
    ws.tabs[0].groupID = TabGroup.unassigned
    ws.tabGroups = []
    ws.focusedGroupByWorktree = [:]

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "ungrouped tabs")
    #expect(ws.tabGroups.count == 1, "one column, not one each")
    #expect(ws.tabs.allSatisfy { $0.groupID == ws.tabGroups[0].id })
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id, "the first tab of the column shows")
  }

  /// A column whose group decoded badly and was dropped leaves its tabs
  /// behind. They join the column the worktree still has rather than
  /// opening a second one beside it.
  @Test func aTabWhoseColumnIsGoneJoinsTheWorktreesFirstColumn() {
    var (ws, tab) = sound()
    let stray = session()
    ws.sessions.append(stray)
    ws.tabs.append(TerminalTab(worktreeID: worktree.id, groupID: UUID(), session: stray.id))

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "orphan tab")
    #expect(ws.tabGroups.count == 1)
    #expect(ws.tabs.count == 2)
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id)
  }

  /// Two columns, and the focused one is emptied by the pane pass. The
  /// focus has to land on the column that is left, or the worktree draws no
  /// strip at all.
  @Test func aColumnLeftWithNoTabsGoesAndTheFocusMovesOn() {
    var (ws, tab) = sound()
    var second = TabGroup(worktreeID: worktree.id)
    let doomed = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: UUID())
    second.activeTabID = doomed.id
    ws.tabGroups.append(second)
    ws.tabs.append(doomed)
    ws.focusedGroupByWorktree[worktree.id] = second.id

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "emptied column")
    #expect(ws.tabGroups.map(\.id) == [onlyGroup(ws).id])
    #expect(ws.focusedGroupByWorktree[worktree.id] == onlyGroup(ws).id)
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id)
  }

  @Test func aColumnShowingAnotherColumnsTabIsCorrected() {
    var (ws, tab) = sound()
    let other = session()
    var second = TabGroup(worktreeID: worktree.id)
    let itsOwn = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: other.id)
    // Pointing at the first column's tab, which is not one of its own.
    second.activeTabID = tab.id
    ws.sessions.append(other)
    ws.tabGroups.append(second)
    ws.tabs.append(itsOwn)

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "column showing a foreign tab")
    #expect(ws.tabGroups[1].activeTabID == itsOwn.id)
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
    var (ws, _) = sound()
    let ghost = UUID()
    let damage: [(inout Workspace) -> Void] = [
      {
        $0.sessions.append(
          TerminalSession(
            worktreeID: "/nowhere", workingDirectory: URL(fileURLWithPath: "/n"), title: "x"))
      },
      {
        $0.tabs.append(
          TerminalTab(worktreeID: "/nowhere", groupID: TabGroup.unassigned, session: ghost))
      },
      { $0.tabGroups[0].activeTabID = UUID() },
      { $0.tabGroups.append(TabGroup(worktreeID: "/nowhere")) },
      { $0.tabGroups.append($0.tabGroups[0]) },
      { $0.tabGroups[0].weight = 0 },
      { $0.focusedGroupByWorktree[$0.worktrees[0].id] = UUID() },
      { $0.focusedGroupByWorktree["/nowhere"] = $0.tabGroups[0].id },
      // Every tab of a state file written before columns existed.
      { ws in for index in ws.tabs.indices { ws.tabs[index].groupID = TabGroup.unassigned } },
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
            worktreeID: $0.worktrees[0].id, groupID: $0.tabGroups[0].id,
            root: .split(axis: .horizontal, children: []), focusedSessionID: ghost))
      },
      { $0.projects.append($0.projects[0]) },
      { $0.worktrees.append($0.worktrees[0]) },
      { ws in ws.sessions.append(ws.sessions[0]) },
      { ws in ws.sessions[0].worktreeID = "/nowhere" },
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
    #expect(ws.tabGroups.isEmpty, "a column with no tabs does not stand")
    #expect(ws.focusedGroupByWorktree[worktree.id] == nil)
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
    // The tabs arrive naming no column, which is the shape of every state
    // file written before columns existed: repair gives them the one they
    // were saved as.
    return ws
  }

  private func session() -> TerminalSession {
    TerminalSession(worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
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

/// The store never adds the same project or worktree twice, but a state
/// file can hold one twice: a hand edit, or two spellings of one path that
/// normalise to the same identity. Every view keys on identity, and the
/// New Worktree picker's labels are a dictionary that traps on a repeat.
@Suite
struct WorkspaceRepairDuplicateTests {
  /// The same as the tab case below, one collection up: the dead copy is the
  /// one kept, the prune then drops it, and its tabs and sessions go too.
  @Test func aWorktreeIdListedTwiceKeepsTheCopyWhoseProjectIsStillThere() throws {
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [ { "path": "file:///repos/demo/" } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/gone", "head": "a", "branch": "dead" },
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "live" } ] }
        """#.utf8))
    #expect(ws.worktrees.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate worktree")
    #expect(ws.worktrees.map(\.branch) == ["live"], "the dead copy was kept and then pruned")
  }

  /// First entry wins, so deduping before the dangling prune can keep the
  /// copy naming a worktree that has gone and lose the live one with it.
  @Test func aTabIdListedTwiceKeepsTheCopyWhoseWorktreeIsStillThere() throws {
    let tab = UUID().uuidString
    let dead = UUID().uuidString
    let live = UUID().uuidString
    var ws = try JSONDecoder().decode(
      Workspace.self,
      from: Data(
        #"""
        { "projects": [ { "path": "file:///repos/demo/" } ],
          "worktrees": [
            { "path": "file:///repos/demo/", "projectID": "/repos/demo", "head": "a", "branch": "main" } ],
          "tabs": [
            { "id": "\#(tab)", "worktreeID": "/repos/gone",
              "root": { "terminal": { "_0": "\#(dead)" } }, "focusedSessionID": "\#(dead)" },
            { "id": "\#(tab)", "worktreeID": "/repos/demo",
              "root": { "terminal": { "_0": "\#(live)" } }, "focusedSessionID": "\#(live)" } ],
          "sessions": [
            { "id": "\#(live)", "worktreeID": "/repos/demo",
              "workingDirectory": "file:///repos/demo/", "title": "Shell" } ] }
        """#.utf8))
    #expect(ws.tabs.count == 2, "decoding keeps both; repair is where they meet")

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "duplicate tab")
    #expect(ws.tabs.map(\.worktreeID) == ["/repos/demo"], "the dead copy was kept and then pruned")
    #expect(ws.sessions.map(\.id.uuidString) == [live], "its session went with it")
  }

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
