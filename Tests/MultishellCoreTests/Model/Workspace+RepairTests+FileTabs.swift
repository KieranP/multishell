import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceRepairTests {
  @Test func aGroupHoldingOnlyFileTabsSurvivesARelaunch() throws {
    var (workspace, tab) = consistentWorkspace()
    var group = TabGroup(worktreeID: tab.worktreeID)
    let file = FileTab(worktreeID: tab.worktreeID, groupID: group.id, path: "README.md")
    group.shownTabID = file.id
    group.tabOrder = [file.id]
    workspace.tabGroups.append(group)
    workspace.fileTabs = [file]

    let reloaded = try decodeJSON(
      Workspace.self,
      String(decoding: try JSONEncoder().encode(workspace), as: UTF8.self),
    )
    var repaired = reloaded
    repaired.repair()

    #expect(repaired == workspace)
  }

  @Test func aFileTabWhoseGroupWentJoinsItsWorktreesFirstGroup() {
    var (workspace, tab) = consistentWorkspace()
    let file = FileTab(worktreeID: tab.worktreeID, groupID: UUID(), path: "a.txt")
    workspace.fileTabs = [file]

    workspace.repair()

    #expect(workspace.fileTab(file.id)?.groupID == tab.groupID)
    #expect(workspace.group(tab.groupID)?.tabOrder == [tab.id, file.id])
  }

  @Test func aFileTabAloneInItsWorktreeGetsAGroupMadeForIt() throws {
    var (workspace, _) = consistentWorkspace()
    let project = try #require(workspace.projects.first)
    let other = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-b"),
      projectID: project.id,
      head: "b",
      branch: "b",
    )
    workspace.worktrees.append(other)
    let file = FileTab(worktreeID: other.id, groupID: UUID(), path: "a.txt")
    workspace.fileTabs = [file]

    workspace.repair()

    let group = try #require(workspace.groups(in: other.id).first)
    #expect(group.shownTabID == file.id && group.tabOrder == [file.id])
    #expect(workspace.focusedGroupByWorktree[other.id] == group.id)
  }

  @Test func aFileTabIsDroppedForAGoneWorktreeAnEscapingPathATakenIdOrARepeatedPath() {
    var (workspace, tab) = consistentWorkspace()
    let kept = FileTab(worktreeID: tab.worktreeID, groupID: tab.groupID, path: "a.txt")
    workspace.fileTabs = [
      kept,
      FileTab(worktreeID: "/repos/gone", groupID: tab.groupID, path: "a.txt"),
      FileTab(worktreeID: tab.worktreeID, groupID: tab.groupID, path: "../a.txt"),
      FileTab(worktreeID: tab.worktreeID, groupID: tab.groupID, path: "a.txt"),
    ]
    let clash = try? decodeJSON(
      FileTab.self,
      #"{"id":"\#(tab.id)","worktreeID":"\#(tab.worktreeID)","path":"b.txt"}"#,
    )
    workspace.fileTabs += clash.map { [$0] } ?? []

    workspace.repair()

    #expect(workspace.fileTabs.map(\.id) == [kept.id])
    #expect(workspace.tab(tab.id) != nil, "the terminal tab keeps its id")
  }

  @Test func anOlderBuildsFileTakesItsStripOrderFromTheTabs() throws {
    var (workspace, tab) = consistentWorkspace()
    let session = TerminalSession(
      worktreeID: tab.worktreeID,
      workingDirectory: URL(fileURLWithPath: "/repos/demo"),
      title: "sh",
    )
    let second = TerminalTab(worktreeID: tab.worktreeID, groupID: tab.groupID, session: session.id)
    workspace.sessions.append(session)
    workspace.tabs.insert(second, at: 0)
    let index = try #require(workspace.groupIndex(tab.groupID))
    workspace.tabGroups[index].tabOrder = []

    workspace.repair()

    #expect(workspace.group(tab.groupID)?.tabOrder == [second.id, tab.id])
  }
}
