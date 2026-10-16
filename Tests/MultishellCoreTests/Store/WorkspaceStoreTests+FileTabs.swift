import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func aFileOpensLastInTheFocusedGroupAndMakesNoSession() throws {
    let (store, _, worktree) = demoStore()
    let shell = try #require(store.openTab(in: worktree.id))

    let file = try #require(store.openFileTab(path: "Sources/App.swift", in: worktree.id))

    let group = try #require(store.workspace.focusedGroup(in: worktree.id))
    #expect(store.workspace.workspaceTabs(inGroup: group.id).map(\.id) == [shell.id, file.id])
    #expect(group.shownTabID == file.id)
    #expect(store.workspace.sessions.count == 1)
    #expect(store.workspace.activeTab(in: worktree.id) == nil, "no terminal tab is in front")
    WorkspaceInvariants.check(store.workspace, "file opened")
  }

  @Test func openingAFileAlreadyOpenTurnsToItsTab() throws {
    let (store, _, worktree) = demoStore()
    let file = try #require(store.openFileTab(path: "README.md", in: worktree.id))
    store.openTab(in: worktree.id)

    let again = store.openFileTab(path: "README.md", in: worktree.id)

    #expect(again?.id == file.id)
    #expect(store.workspace.fileTabs.count == 1)
    #expect(store.workspace.activeWorkspaceTab(in: worktree.id)?.id == file.id)
  }

  @Test func aPathLeavingTheWorktreeOpensNoTab() {
    let (store, _, worktree) = demoStore()

    for path in ["", "../secret", "/etc/hosts", "a//b", "a/./b"] {
      #expect(store.openFileTab(path: path, in: worktree.id) == nil, "\(path)")
    }
    #expect(store.workspace.fileTabs.isEmpty)
  }

  @Test func aGroupOfFileTabsAloneStandsAndClosesWithItsLastOne() throws {
    let (store, _, worktree) = demoStore()
    let first = try #require(store.openFileTab(path: "a.txt", in: worktree.id))
    let second = try #require(store.openFileTab(path: "b.txt", in: worktree.id))

    store.closeTab(second.id)

    #expect(store.workspace.groups(in: worktree.id).first?.shownTabID == first.id)
    store.closeTab(first.id)
    #expect(store.workspace.groups(in: worktree.id).isEmpty)
    WorkspaceInvariants.check(store.workspace, "closed")
  }

  @Test func fileAndTerminalTabsReorderTogetherAndTheArrayFollowsForAnOlderBuild() throws {
    let (store, _, worktree) = demoStore()
    let one = try #require(store.openTab(in: worktree.id))
    let file = try #require(store.openFileTab(path: "a.txt", in: worktree.id))
    let two = try #require(store.openTab(in: worktree.id))

    #expect(store.moveTab(two.id, .before, anchor: file.id))
    #expect(store.moveTab(one.id, .after, anchor: file.id))

    let group = try #require(store.workspace.groups(in: worktree.id).first)
    #expect(
      store.workspace.workspaceTabs(inGroup: group.id).map(\.id) == [two.id, file.id, one.id]
    )
    #expect(store.workspace.tabs.map(\.id) == [two.id, one.id])
    WorkspaceInvariants.check(store.workspace, "reordered")
  }

  @Test func aFileTabMovesToANewGroupButNeverToAnotherWorktree() throws {
    let (store, main, other) = twoWorktreeStore()
    store.openTab(in: main.id)
    let file = try #require(store.openFileTab(path: "a.txt", in: main.id))
    let first = try #require(store.workspace.groups(in: main.id).first)

    #expect(!store.moveTab(file.id, toWorktree: other.id))
    let made = try #require(store.moveTab(file.id, .after, toNewGroupOf: first.id))

    #expect(store.workspace.fileTab(file.id)?.groupID == made.id)
    #expect(store.workspace.fileTab(file.id)?.worktreeID == main.id)
    #expect(store.workspace.focusedGroup(in: main.id)?.id == made.id)
    WorkspaceInvariants.check(store.workspace, "new group")
  }

  @Test func aDiscardedWorktreeTakesItsFileTabs() throws {
    let (store, project, worktree) = demoStore()
    store.openFileTab(path: "a.txt", in: worktree.id)

    store.replaceWorktrees([], forProject: project.id)

    #expect(store.workspace.fileTabs.isEmpty)
  }

  @Test func aClosedFileTabHandsItsPlaceToTheTabThatSlidIn() throws {
    let (store, _, worktree) = demoStore()
    let shell = try #require(store.openTab(in: worktree.id))
    let file = try #require(store.openFileTab(path: "a.txt", in: worktree.id))
    let last = try #require(store.openTab(in: worktree.id))
    store.activateTab(file.id)

    store.closeTab(file.id)

    #expect(store.workspace.groups(in: worktree.id).first?.shownTabID == last.id)
    #expect(store.workspace.tabs.map(\.id) == [shell.id, last.id])
  }
}
