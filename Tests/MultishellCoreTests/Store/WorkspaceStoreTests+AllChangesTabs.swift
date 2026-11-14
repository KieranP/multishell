import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func anAllChangesTabOpensLastInTheFocusedGroupAndMakesNoSession() throws {
    let (store, _, worktree) = demoStore()
    let shell = try #require(store.openTab(in: worktree.id))

    let allChanges = try #require(store.openAllChangesTab(in: worktree.id))

    let group = try #require(store.workspace.focusedGroup(in: worktree.id))
    #expect(
      store.workspace.workspaceTabs(inGroup: group.id).map(\.id) == [shell.id, allChanges.id]
    )
    #expect(group.shownTabID == allChanges.id)
    #expect(store.workspace.sessions.count == 1)
    #expect(store.workspace.activeTab(in: worktree.id) == nil, "no terminal tab is in front")
    WorkspaceInvariants.check(store.workspace, "All changes opened")
  }

  @Test func openingAllChangesAgainTurnsToTheWorktreesOneTab() throws {
    let (store, _, worktree) = demoStore()
    let first = try #require(store.openAllChangesTab(in: worktree.id))
    store.openTab(in: worktree.id)

    let again = store.openAllChangesTab(in: worktree.id)

    #expect(again?.id == first.id)
    #expect(store.workspace.allChangesTabs.count == 1)
    #expect(store.workspace.activeWorkspaceTab(in: worktree.id)?.id == first.id)
  }

  @Test func eachWorktreeHasAnAllChangesTabOfItsOwn() throws {
    let (store, main, other) = twoWorktreeStore()

    let mainTab = try #require(store.openAllChangesTab(in: main.id))
    let otherTab = try #require(store.openAllChangesTab(in: other.id))

    #expect(mainTab.id != otherTab.id)
    #expect(store.workspace.allChangesTab(in: main.id)?.id == mainTab.id)
    #expect(store.workspace.allChangesTab(in: other.id)?.id == otherTab.id)
    WorkspaceInvariants.check(store.workspace, "two worktrees")
  }

  @Test func aWorktreeNotListedOpensNoAllChangesTab() {
    let (store, _, _) = demoStore()

    #expect(store.openAllChangesTab(in: "/repos/gone") == nil)
    #expect(store.workspace.allChangesTabs.isEmpty)
  }

  @Test func aClosedAllChangesTabHandsItsPlaceToTheTabThatSlidIn() throws {
    let (store, _, worktree) = demoStore()
    let shell = try #require(store.openTab(in: worktree.id))
    let allChanges = try #require(store.openAllChangesTab(in: worktree.id))
    let last = try #require(store.openTab(in: worktree.id))
    store.activateTab(allChanges.id)

    store.closeTab(allChanges.id)

    #expect(store.workspace.allChangesTabs.isEmpty)
    #expect(store.workspace.groups(in: worktree.id).first?.shownTabID == last.id)
    #expect(store.workspace.tabs.map(\.id) == [shell.id, last.id])
    WorkspaceInvariants.check(store.workspace, "closed")
  }

  @Test func aGroupHoldingOnlyTheAllChangesTabClosesWithIt() throws {
    let (store, _, worktree) = demoStore()
    let allChanges = try #require(store.openAllChangesTab(in: worktree.id))

    store.closeTab(allChanges.id)

    #expect(store.workspace.groups(in: worktree.id).isEmpty)
    WorkspaceInvariants.check(store.workspace, "closed")
  }

  @Test func theAllChangesTabReordersAmongTheOtherKinds() throws {
    let (store, _, worktree) = demoStore()
    let shell = try #require(store.openTab(in: worktree.id))
    let file = try #require(store.openFileTab(path: "a.txt", in: worktree.id))
    let allChanges = try #require(store.openAllChangesTab(in: worktree.id))

    #expect(store.moveTab(allChanges.id, .before, anchor: shell.id))
    #expect(store.moveTab(file.id, .before, anchor: allChanges.id))

    let group = try #require(store.workspace.groups(in: worktree.id).first)
    #expect(
      store.workspace.workspaceTabs(inGroup: group.id).map(\.id)
        == [file.id, allChanges.id, shell.id]
    )
    WorkspaceInvariants.check(store.workspace, "reordered")
  }

  @Test func theAllChangesTabMovesToANewGroupButNeverToAnotherWorktree() throws {
    let (store, main, other) = twoWorktreeStore()
    store.openTab(in: main.id)
    let allChanges = try #require(store.openAllChangesTab(in: main.id))
    let first = try #require(store.workspace.groups(in: main.id).first)

    #expect(!store.moveTab(allChanges.id, toWorktree: other.id))
    let made = try #require(store.moveTab(allChanges.id, .after, toNewGroupOf: first.id))

    #expect(store.workspace.allChangesTab(allChanges.id)?.groupID == made.id)
    #expect(store.workspace.allChangesTab(allChanges.id)?.worktreeID == main.id)
    WorkspaceInvariants.check(store.workspace, "new group")
  }

  @Test func aDiscardedWorktreeTakesItsAllChangesTab() {
    let (store, project, worktree) = demoStore()
    store.openAllChangesTab(in: worktree.id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.allChangesTabs.isEmpty)
  }
}
