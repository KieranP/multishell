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

  private func onlyGroup(_ workspace: Workspace) -> TabGroup { workspace.tabGroups[0] }

  /// Every tab of a state file written before groups existed names no group.
  static func ungroupEveryTab(_ workspace: inout Workspace) {
    for index in workspace.tabs.indices { workspace.tabs[index].groupID = TabGroup.unassigned }
  }

  @Test func aConsistentWorkspaceIsLeftAlone() {
    let (workspace, _) = consistentWorkspace()
    var repaired = workspace
    repaired.repairReferences()
    #expect(repaired == workspace)
  }

  @Test func worktreesOfAMissingProjectGoWithTheirTabs() {
    var (workspace, _) = consistentWorkspace()
    let stray = Worktree(
      path: URL(fileURLWithPath: "/repos/x"), projectID: "/repos/gone", head: "b")
    let straySession = TerminalSession(
      worktreeID: stray.id, workingDirectory: stray.path, title: "sh")
    let strayGroup = TabGroup(worktreeID: stray.id)
    workspace.worktrees.append(stray)
    workspace.sessions.append(straySession)
    workspace.tabGroups.append(strayGroup)
    workspace.tabs.append(
      TerminalTab(worktreeID: stray.id, groupID: strayGroup.id, session: straySession.id))

    workspace.repairReferences()

    #expect(workspace.worktrees.map(\.id) == [worktree.id])
    #expect(workspace.tabs.count == 1 && workspace.sessions.count == 1)
    #expect(workspace.tabGroups.count == 1, "the group went with the worktree")
  }

  @Test func aSessionNoTabOwnsIsDropped() {
    var (workspace, tab) = consistentWorkspace()
    workspace.sessions.append(session())

    workspace.repairReferences()

    #expect(workspace.sessions.map(\.id) == [tab.focusedSessionID])
  }

  @Test func aPaneWhoseSessionIsMissingCollapsesAndTheTabSurvives() {
    var (workspace, tab) = consistentWorkspace()
    let ghost = UUID()
    var split = tab
    split.root = .split(
      axis: .horizontal, children: [.terminal(tab.focusedSessionID), .terminal(ghost)])
    split.focusedSessionID = ghost
    workspace.tabs = [split]

    workspace.repairReferences()

    #expect(workspace.tabs[0].root == .terminal(tab.focusedSessionID))
    #expect(
      workspace.tabs[0].focusedSessionID == tab.focusedSessionID,
      "focus cannot point outside the tree")
  }

  @Test func aTabWithNoLiveSessionsIsRemovedAndTheActiveEntryMovesOn() {
    var (workspace, tab) = consistentWorkspace()
    let empty = TerminalTab(
      worktreeID: worktree.id, groupID: onlyGroup(workspace).id, session: UUID())
    workspace.tabs.append(empty)
    workspace.tabGroups[0].shownTabID = empty.id

    workspace.repairReferences()

    #expect(workspace.tabs.map(\.id) == [tab.id])
    #expect(
      workspace.tabGroups[0].shownTabID == tab.id, "otherwise the group shows nothing")
  }

  @Test func aFocusedGroupEntryNamingAnotherWorktreesGroupIsCorrected() {
    var (workspace, tab) = consistentWorkspace()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    workspace.worktrees.append(other)
    workspace.focusedGroupByWorktree[other.id] = onlyGroup(workspace).id

    workspace.repairReferences()

    #expect(workspace.focusedGroupByWorktree[other.id] == nil)
    #expect(workspace.focusedGroupByWorktree[worktree.id] == onlyGroup(workspace).id)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)
  }

  @Test func aNameForAMissingWorktreeGoesAndABlankOneWithIt() {
    var (workspace, _) = consistentWorkspace()
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"), projectID: project.id, head: "b")
    workspace.worktrees.append(other)
    workspace.worktreeNames = [worktree.id: "Checkout", other.id: "  ", "/repos/nowhere": "Ghost"]

    workspace.repairReferences()

    #expect(workspace.worktreeNames == [worktree.id: "Checkout"])
  }

  /// The store writes a session's worktree with its tab's, so a file where they disagree was
  /// written by something else; the sidebar lists it under the tab, so the tab decides.
  @Test func aSessionSaidToBeInAnotherWorktreeThanItsTabIsPutBack() {
    var (workspace, tab) = consistentWorkspace()
    workspace.sessions[0].worktreeID = "/repos/nowhere"

    workspace.repairReferences()

    #expect(workspace.sessions.count == 1, "the session is the tab's, not a stray")
    #expect(workspace.sessions[0].worktreeID == workspace.tab(tab.id)?.worktreeID)
    #expect(
      workspace.sessions[0].workingDirectory == worktree.path,
      "the directory it starts in comes back with it")
  }

  @Test func tabsThatNameNoGroupAreGatheredIntoOne() {
    var (workspace, tab) = consistentWorkspace()
    let second = session()
    workspace.sessions.append(second)
    workspace.tabs.append(
      TerminalTab(worktreeID: worktree.id, groupID: TabGroup.unassigned, session: second.id))
    Self.ungroupEveryTab(&workspace)
    workspace.tabGroups = []
    workspace.focusedGroupByWorktree = [:]

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "ungrouped tabs")
    #expect(workspace.tabGroups.count == 1, "one group, not one each")
    #expect(workspace.tabs.allSatisfy { $0.groupID == workspace.tabGroups[0].id })
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id, "the first tab of the group shows")
  }

  /// A group that decoded badly is dropped and leaves its tabs behind.
  @Test func aTabWhoseGroupIsGoneJoinsTheWorktreesFirstGroup() {
    var (workspace, tab) = consistentWorkspace()
    let stray = session()
    workspace.sessions.append(stray)
    workspace.tabs.append(TerminalTab(worktreeID: worktree.id, groupID: UUID(), session: stray.id))

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "orphan tab")
    #expect(workspace.tabGroups.count == 1)
    #expect(workspace.tabs.count == 2)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)
  }

  /// The pane pass empties the focused group, and unless the focus moves on the worktree draws
  /// no strip at all.
  @Test func aGroupLeftWithNoTabsGoesAndTheFocusMovesOn() {
    var (workspace, tab) = consistentWorkspace()
    var second = TabGroup(worktreeID: worktree.id)
    let doomed = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: UUID())
    second.shownTabID = doomed.id
    workspace.tabGroups.append(second)
    workspace.tabs.append(doomed)
    workspace.focusedGroupByWorktree[worktree.id] = second.id

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "emptied group")
    #expect(workspace.tabGroups.map(\.id) == [onlyGroup(workspace).id])
    #expect(workspace.focusedGroupByWorktree[worktree.id] == onlyGroup(workspace).id)
    #expect(workspace.activeTab(in: worktree.id)?.id == tab.id)
  }

  @Test func aGroupShowingAnotherGroupsTabIsCorrected() {
    var (workspace, tab) = consistentWorkspace()
    let other = session()
    var second = TabGroup(worktreeID: worktree.id)
    let itsOwn = TerminalTab(worktreeID: worktree.id, groupID: second.id, session: other.id)
    // Pointing at the first group's tab, which is not one of its own.
    second.shownTabID = tab.id
    workspace.sessions.append(other)
    workspace.tabGroups.append(second)
    workspace.tabs.append(itsOwn)

    workspace.repairReferences()

    WorkspaceInvariants.check(workspace, "group showing a foreign tab")
    #expect(workspace.tabGroups[1].shownTabID == itsOwn.id)
  }

  @Test func aSelectionOfAMissingWorktreeIsCleared() {
    var (workspace, _) = consistentWorkspace()
    workspace.selectedWorktreeID = "/repos/nowhere"
    workspace.repairReferences()
    #expect(workspace.selectedWorktreeID == nil)
  }

  @Test(arguments: [7, 11, 19, 23, 29, 31] as [UInt64])
  func repairIsCompleteAndIdempotentOnRandomDamage(seed: UInt64) {
    var rng = SeededGenerator(seed: seed)
    var (workspace, _) = consistentWorkspace()
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
      { $0.tabGroups[0].shownTabID = UUID() },
      { $0.tabGroups.append(TabGroup(worktreeID: "/nowhere")) },
      { $0.tabGroups.append($0.tabGroups[0]) },
      { $0.tabGroups[0].weight = 0 },
      { $0.focusedGroupByWorktree[$0.worktrees[0].id] = UUID() },
      { $0.focusedGroupByWorktree["/nowhere"] = $0.tabGroups[0].id },
      Self.ungroupEveryTab,
      { $0.selectedWorktreeID = "/nowhere" },
      { $0.worktreeNames["/nowhere"] = "Ghost" },
      { $0.worktreeNames[$0.worktrees[0].id] = "  " },
      {
        $0.worktrees.append(
          Worktree(path: URL(fileURLWithPath: "/x"), projectID: "/gone", head: "h"))
      },
      { workspace in
        var split = workspace.tabs[0]
        split.root = .split(
          axis: .vertical, children: [.terminal(ghost), split.root], weights: [1])
        split.focusedSessionID = ghost
        workspace.tabs[0] = split
      },
      {
        $0.tabs.append(
          TerminalTab(
            worktreeID: $0.worktrees[0].id, groupID: $0.tabGroups[0].id,
            root: .split(axis: .horizontal, children: []), focusedSessionID: ghost))
      },
      { $0.projects.append($0.projects[0]) },
      { $0.worktrees.append($0.worktrees[0]) },
      { workspace in workspace.sessions.append(workspace.sessions[0]) },
      { workspace in workspace.sessions[0].worktreeID = "/nowhere" },
    ]
    for _ in 0..<Int.random(in: 1...6, using: &rng) {
      damage.randomElement(using: &rng)!(&workspace)
    }

    workspace.repairReferences()
    WorkspaceInvariants.check(workspace, "seed \(seed)")
    var again = workspace
    again.repairReferences()
    #expect(again == workspace, "seed \(seed): repair is not idempotent")
    #expect(workspace.projects.count == 1, "seed \(seed): repair must never drop a project")
  }
}
