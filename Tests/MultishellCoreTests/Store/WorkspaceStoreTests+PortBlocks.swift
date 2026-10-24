import Foundation
import Testing

@testable import MultishellCore

extension WorkspaceStoreTests {
  @Test func eachListedWorktreeTakesTheLowestFreeBlockAcrossProjects() {
    let (store, main, other) = twoWorktreeStore()
    let second = store.addProject(at: URL(fileURLWithPath: "/repos/second"))
    let secondMain = Worktree(
      path: second.path,
      projectID: second.id,
      head: "c",
      branch: "main",
      isPrimary: true,
    )
    store.replaceWorktrees([secondMain], forProject: second.id)

    #expect(store.workspace.port(of: main.id) == 3000)
    #expect(store.workspace.port(of: other.id) == 3010)
    #expect(store.workspace.port(of: secondMain.id) == 3020)
  }

  @Test func aBareRepositoryTakesNoBlock() {
    let store = WorkspaceStore()
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/bare.git"))
    let bare = Worktree(path: project.path, projectID: project.id, head: "", isBare: true)
    let linked = Worktree(
      path: URL(fileURLWithPath: "/repos/feat"),
      projectID: project.id,
      head: "a",
      branch: "feat",
    )
    store.replaceWorktrees([bare, linked], forProject: project.id)

    #expect(store.workspace.port(of: bare.id) == nil)
    #expect(store.workspace.port(of: linked.id) == 3000)
  }

  @Test func aWorktreeGoneFromGitsListFreesItsBlockForTheNextOne() {
    let (store, main, other) = twoWorktreeStore()
    store.replaceWorktrees([other], forProject: main.projectID)
    let next = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-c"),
      projectID: main.projectID,
      head: "c",
      branch: "c",
    )
    store.replaceWorktrees([other, next], forProject: main.projectID)

    #expect(store.workspace.port(of: other.id) == 3010)
    #expect(store.workspace.port(of: next.id) == 3000)
  }

  @Test func aWorktreeKeptForItsRemovalKeepsItsBlockUntilARefreshDropsIt() {
    let (store, main, other) = twoWorktreeStore()
    let next = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-c"),
      projectID: main.projectID,
      head: "c",
      branch: "c",
    )

    store.replaceWorktrees([main, next], forProject: main.projectID, keeping: [other.id])
    #expect(store.workspace.port(of: other.id) == 3010)
    #expect(store.workspace.port(of: next.id) == 3020)

    store.replaceWorktrees([main, next], forProject: main.projectID)
    #expect(store.workspace.worktree(other.id) == nil)
    #expect(store.workspace.portBlocks[other.id] == nil)
    #expect(store.workspace.port(of: next.id) == 3020, "a freed block moves no one")
  }

  @Test func aWorktreeListedAgainAtAKeptPathTakesAFreshBlock() {
    let (store, main, other) = twoWorktreeStore()
    store.replaceWorktrees([main], forProject: main.projectID, keeping: [other.id])

    store.replaceWorktrees([main, other], forProject: main.projectID, keeping: [other.id])

    #expect(store.workspace.port(of: other.id) == 3020, "3010 is the removal's hook's")
  }

  @Test func aRemovalsHookKeepsItsBlockFromTheNextWorktreeWhileItRuns() {
    let (store, main, other) = twoWorktreeStore()
    store.replaceWorktrees([main], forProject: main.projectID, keeping: [other.id])
    store.replaceWorktrees([main, other], forProject: main.projectID, keeping: [other.id])
    let next = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-c"),
      projectID: main.projectID,
      head: "c",
      branch: "c",
    )

    store.replaceWorktrees([main, other, next], forProject: main.projectID, keeping: [other.id])

    #expect(store.workspace.port(of: next.id) == 3030)
  }

  @Test func aRemovalsHookFreesItsBlockOnceThatRemovalEnds() {
    let (store, main, other) = twoWorktreeStore()
    store.replaceWorktrees([main], forProject: main.projectID, keeping: [other.id])
    store.replaceWorktrees([main, other], forProject: main.projectID, keeping: [other.id])
    store.replaceWorktrees([main, other], forProject: main.projectID)
    let next = Worktree(
      path: URL(fileURLWithPath: "/repos/demo-c"),
      projectID: main.projectID,
      head: "c",
      branch: "c",
    )

    store.replaceWorktrees([main, other, next], forProject: main.projectID)

    #expect(store.workspace.port(of: next.id) == 3010)
  }

  @Test func aRemovedProjectFreesItsWorktreesBlocks() {
    let (store, project, worktree) = demoStore()
    store.removeProject(project.id)
    let again = store.addProject(at: URL(fileURLWithPath: "/repos/again"))
    let main = Worktree(path: again.path, projectID: again.id, head: "a", isPrimary: true)
    store.replaceWorktrees([main], forProject: again.id)

    #expect(store.workspace.port(of: worktree.id) == nil)
    #expect(store.workspace.port(of: main.id) == 3000)
  }

  @Test func aRemovedProjectsBlockGoesToAWorktreeThatHadNone() {
    let store = WorkspaceStore()
    store.setPortBlockStart(65_526)
    let first = store.addProject(at: URL(fileURLWithPath: "/repos/first"))
    let second = store.addProject(at: URL(fileURLWithPath: "/repos/second"))
    let firstMain = Worktree(path: first.path, projectID: first.id, head: "a", isPrimary: true)
    let secondMain = Worktree(path: second.path, projectID: second.id, head: "b", isPrimary: true)
    store.replaceWorktrees([firstMain], forProject: first.id)
    store.replaceWorktrees([secondMain], forProject: second.id)
    #expect(store.workspace.port(of: secondMain.id) == nil)

    store.removeProject(first.id)

    #expect(store.workspace.port(of: secondMain.id) == 65_526)
  }

  @Test func changingTheStartOrSizeKeepsEachBlockAndMovesItsPorts() {
    let (store, main, other) = twoWorktreeStore()
    store.setPortBlockStart(4000)
    store.setPortBlockSize(100)

    #expect(store.workspace.port(of: main.id) == 4000)
    #expect(store.workspace.port(of: other.id) == 4100)
  }

  @Test func aBlockThatWouldEndPast65535IsNotGiven() {
    let store = WorkspaceStore()
    store.setPortBlockStart(65_520)
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let worktrees = ["a", "b", "c"].map { name in
      Worktree(
        path: URL(fileURLWithPath: "/repos/\(name)"),
        projectID: project.id,
        head: name,
        branch: name,
      )
    }
    store.replaceWorktrees(worktrees, forProject: project.id)

    #expect(worktrees.map { store.workspace.port(of: $0.id) } == [65_520, nil, nil])
    #expect(store.workspace.worktreesWithoutPorts.map(\.id) == [worktrees[1].id, worktrees[2].id])
  }

  @Test func aBlockMovedPast65535BySettingsLosesItsPortButKeepsItsPlace() {
    let (store, main, other) = twoWorktreeStore()
    store.setPortBlockStart(65_520)

    #expect(store.workspace.port(of: main.id) == 65_520)
    #expect(store.workspace.port(of: other.id) == nil)

    store.setPortBlockStart(3000)
    #expect(store.workspace.port(of: other.id) == 3010)
  }

  @Test func aBlockFreedBelowTheEndGoesToAWorktreeWhoseBlockNoLongerFits() {
    let (store, main, other) = twoWorktreeStore()
    store.setPortBlockStart(65_526)
    #expect(store.workspace.port(of: other.id) == nil)

    store.replaceWorktrees([other], forProject: main.projectID)

    #expect(store.workspace.port(of: other.id) == 65_526)
  }

  @Test func settingsThatMakeRoomGiveAWorktreeWithoutABlockOne() {
    let store = WorkspaceStore()
    store.setPortBlockStart(65_530)
    let project = store.addProject(at: URL(fileURLWithPath: "/repos/demo"))
    let main = Worktree(path: project.path, projectID: project.id, head: "a", isPrimary: true)
    store.replaceWorktrees([main], forProject: project.id)
    #expect(store.workspace.port(of: main.id) == nil)

    store.setPortBlockSize(5)

    #expect(store.workspace.port(of: main.id) == 65_530)
  }

  @Test func aStartBelow1024OrASizeBelowOneIsRaisedToTheFloor() {
    let store = WorkspaceStore()
    store.setPortBlockStart(80)
    store.setPortBlockSize(0)

    #expect(store.workspace.portBlockStart == 1024)
    #expect(store.workspace.portBlockSize == 1)
  }
}
