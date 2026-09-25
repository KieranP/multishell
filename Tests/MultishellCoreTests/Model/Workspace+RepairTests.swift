import Foundation
import TestScratch
import Testing

@testable import MultishellCore

/// State off disk can break an invariant the store keeps: a crash mid-save, a hand edit, or a bug
/// in an earlier build.
@Suite
struct WorkspaceRepairTests {
  let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
  var worktree: Worktree {
    Worktree(path: project.path, projectID: project.id, head: "a", branch: "main", isPrimary: true)
  }

  func session() -> TerminalSession {
    TerminalSession(worktreeID: worktree.id, workingDirectory: worktree.path, title: "sh")
  }

  /// The one group a sound single-group workspace has.
  private func onlyGroup(_ ws: Workspace) -> TabGroup { ws.tabGroups[0] }

  @Test func aSoundWorkspaceIsLeftAlone() {
    let (ws, _) = soundWorkspace()
    var repaired = ws
    repaired.repairReferences()
    #expect(repaired == ws)
  }

  @Test func worktreesOfAMissingProjectGoWithTheirTabs() {
    var (ws, _) = soundWorkspace()
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
    #expect(ws.tabGroups.count == 1, "the group went with the worktree")
  }

  @Test func aSessionNoTabOwnsIsDropped() {
    var (ws, tab) = soundWorkspace()
    ws.sessions.append(session())

    ws.repairReferences()

    #expect(ws.sessions.map(\.id) == [tab.focusedSessionID])
  }

  @Test func aPaneWhoseSessionIsMissingCollapsesAndTheTabSurvives() {
    var (ws, tab) = soundWorkspace()
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
    var (ws, tab) = soundWorkspace()
    let empty = TerminalTab(
      worktreeID: worktree.id, groupID: onlyGroup(ws).id, session: UUID())
    ws.tabs.append(empty)
    ws.tabGroups[0].activeTabID = empty.id

    ws.repairReferences()

    #expect(ws.tabs.map(\.id) == [tab.id])
    #expect(
      ws.tabGroups[0].activeTabID == tab.id, "otherwise the group shows nothing")
  }

  @Test func anActiveEntryForAnotherWorktreesTabIsCorrected() {
    var (ws, tab) = soundWorkspace()
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
    var (ws, _) = soundWorkspace()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    ws.worktrees.append(other)
    ws.worktreeNames = [worktree.id: "Checkout", other.id: "  ", "/repos/nowhere": "Ghost"]

    ws.repairReferences()

    #expect(ws.worktreeNames == [worktree.id: "Checkout"])
  }

  /// The store writes a session's worktree with its tab's, so a file where they disagree was
  /// written by something else; the sidebar lists it under the tab, so the tab decides.
  @Test func aSessionSaidToBeInAnotherWorktreeThanItsTabIsPutBack() {
    var (ws, tab) = soundWorkspace()
    ws.sessions[0].worktreeID = "/repos/nowhere"

    ws.repairReferences()

    #expect(ws.sessions.count == 1, "the session is the tab's, not a stray")
    #expect(ws.sessions[0].worktreeID == ws.tab(tab.id)?.worktreeID)
    #expect(
      ws.sessions[0].workingDirectory == worktree.path,
      "the directory it starts in comes back with it")
  }

  /// Every tab of a state file written before groups existed names no group.
  @Test func tabsThatNameNoGroupAreGatheredIntoOne() {
    var (ws, tab) = soundWorkspace()
    let second = session()
    ws.sessions.append(second)
    ws.tabs.append(
      TerminalTab(worktreeID: worktree.id, groupID: TabGroup.unassigned, session: second.id))
    ws.tabs[0].groupID = TabGroup.unassigned
    ws.tabGroups = []
    ws.focusedGroupByWorktree = [:]

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "ungrouped tabs")
    #expect(ws.tabGroups.count == 1, "one group, not one each")
    #expect(ws.tabs.allSatisfy { $0.groupID == ws.tabGroups[0].id })
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id, "the first tab of the group shows")
  }

  /// A group whose group decoded badly is dropped and leaves its tabs behind.
  @Test func aTabWhoseGroupIsGoneJoinsTheWorktreesFirstGroup() {
    var (ws, tab) = soundWorkspace()
    let stray = session()
    ws.sessions.append(stray)
    ws.tabs.append(TerminalTab(worktreeID: worktree.id, groupID: UUID(), session: stray.id))

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "orphan tab")
    #expect(ws.tabGroups.count == 1)
    #expect(ws.tabs.count == 2)
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id)
  }

  /// The pane pass empties the focused group, and unless the focus moves on the worktree draws
  /// no strip at all.
  @Test func aGroupLeftWithNoTabsGoesAndTheFocusMovesOn() {
    var (ws, tab) = soundWorkspace()
    var second = TabGroup(worktreeID: worktree.id)
    let doomed = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: UUID())
    second.activeTabID = doomed.id
    ws.tabGroups.append(second)
    ws.tabs.append(doomed)
    ws.focusedGroupByWorktree[worktree.id] = second.id

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "emptied group")
    #expect(ws.tabGroups.map(\.id) == [onlyGroup(ws).id])
    #expect(ws.focusedGroupByWorktree[worktree.id] == onlyGroup(ws).id)
    #expect(ws.activeTab(in: worktree.id)?.id == tab.id)
  }

  @Test func aGroupShowingAnotherGroupsTabIsCorrected() {
    var (ws, tab) = soundWorkspace()
    let other = session()
    var second = TabGroup(worktreeID: worktree.id)
    let itsOwn = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: other.id)
    // Pointing at the first group's tab, which is not one of its own.
    second.activeTabID = tab.id
    ws.sessions.append(other)
    ws.tabGroups.append(second)
    ws.tabs.append(itsOwn)

    ws.repairReferences()

    WorkspaceInvariants.check(ws, "group showing a foreign tab")
    #expect(ws.tabGroups[1].activeTabID == itsOwn.id)
  }

  @Test func aSelectionOfAMissingWorktreeIsCleared() {
    var (ws, _) = soundWorkspace()
    ws.selectedWorktreeID = "/repos/nowhere"
    ws.repairReferences()
    #expect(ws.selectedWorktreeID == nil)
  }

  @Test(arguments: [7, 11, 19, 23, 29, 31] as [UInt64])
  func repairIsCompleteAndIdempotentOnRandomDamage(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    var (ws, _) = soundWorkspace()
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
      // Every tab of a state file written before groups existed.
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
    var (ws, tab) = soundWorkspace()
    var hollow = tab
    hollow.root = .split(axis: .vertical, children: [])
    ws.tabs = [hollow]

    ws.repairReferences()

    #expect(ws.tabs.isEmpty)
    #expect(ws.sessions.isEmpty)
    #expect(ws.tabGroups.isEmpty, "a group with no tabs does not stand")
    #expect(ws.focusedGroupByWorktree[worktree.id] == nil)
  }
}
