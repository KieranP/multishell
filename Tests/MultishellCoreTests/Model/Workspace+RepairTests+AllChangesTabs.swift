import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceRepairTests {
  @Test func aGroupHoldingOnlyTheAllChangesTabSurvivesARelaunch() throws {
    var (workspace, tab) = consistentWorkspace()
    var group = TabGroup(worktreeID: tab.worktreeID)
    let allChanges = AllChangesTab(worktreeID: tab.worktreeID, groupID: group.id)
    group.shownTabID = allChanges.id
    group.tabOrder = [allChanges.id]
    workspace.tabGroups.append(group)
    workspace.allChangesTabs = [allChanges]

    var reloaded = try decodeJSON(
      Workspace.self,
      String(decoding: try JSONEncoder().encode(workspace), as: UTF8.self),
    )
    reloaded.repair()

    #expect(reloaded == workspace)
  }

  @Test func anAllChangesTabWhoseGroupWentJoinsItsWorktreesFirstGroup() {
    var (workspace, tab) = consistentWorkspace()
    let allChanges = AllChangesTab(worktreeID: tab.worktreeID, groupID: UUID())
    workspace.allChangesTabs = [allChanges]

    workspace.repair()

    #expect(workspace.allChangesTab(allChanges.id)?.groupID == tab.groupID)
    #expect(workspace.group(tab.groupID)?.tabOrder == [tab.id, allChanges.id])
  }

  @Test func anAllChangesTabIsDroppedForAGoneWorktreeATakenIDOrASecondInItsWorktree() throws {
    var (workspace, tab) = consistentWorkspace()
    let file = FileTab(worktreeID: tab.worktreeID, groupID: tab.groupID, path: "a.txt")
    workspace.fileTabs = [file]
    let kept = AllChangesTab(worktreeID: tab.worktreeID, groupID: tab.groupID)
    let takenIDs = try [tab.id, file.id].map { id in
      try decodeJSON(AllChangesTab.self, #"{"id":"\#(id)","worktreeID":"\#(tab.worktreeID)"}"#)
    }
    workspace.allChangesTabs =
      takenIDs + [
        kept,
        AllChangesTab(worktreeID: "/repos/gone", groupID: tab.groupID),
        AllChangesTab(worktreeID: tab.worktreeID, groupID: tab.groupID),
      ]

    workspace.repair()

    #expect(workspace.allChangesTabs.map(\.id) == [kept.id])
    #expect(workspace.tab(tab.id) != nil && workspace.fileTab(file.id) != nil)
    WorkspaceInvariants.check(workspace, "repaired")
  }
}
