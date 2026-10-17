import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite
struct FileChangeTargetsTests {
  private let project = Project(path: URL(fileURLWithPath: "/repos/demo"))
  private var common: URL { URL(fileURLWithPath: "/repos/demo/.git") }
  private var themes: URL { URL(fileURLWithPath: "/support/themes") }
  private var main: Worktree {
    Worktree(
      path: project.path,
      projectID: project.id,
      head: "abc",
      branch: "main",
      isPrimary: true,
    )
  }
  private var nested: Worktree {
    Worktree(
      path: URL(fileURLWithPath: "/repos/demo/.worktrees/side"),
      projectID: project.id,
      head: "abc",
      branch: "side",
    )
  }

  private func targets(_ changed: [String]) -> FileChangeTargets {
    FileChangeTargets(
      changed: changed.map { URL(fileURLWithPath: $0) },
      projects: [project],
      gitDirectories: [project.id: common],
      worktrees: [main, nested],
      themesDirectory: themes,
    )
  }

  @Test func aChangeInTheGitDirectoryIsTheWholeProjects() {
    let found = targets(["/repos/demo/.git/refs"])

    #expect(found.projectsWithGitChanges == [project.id])
    #expect(found.fileChangesByWorktree.isEmpty)
  }

  @Test func gitsScratchFilesCallForNothing() {
    let found = targets(
      [
        "objects", "logs", "FETCH_HEAD", "COMMIT_EDITMSG", "index.lock", "fsmonitor--daemon",
        "worktrees/side/fsmonitor--daemon/cookies", "modules/libs/sub/fsmonitor--daemon/cookies",
        "worktrees/side/fsmonitor--daemon.ipc",
      ]
      .map { "/repos/demo/.git/\($0)" }
    )

    #expect(found.projectsWithGitChanges.isEmpty)
    #expect(found.fileChangesByWorktree.isEmpty)
  }

  @Test func aLockTakenUnderTheGitDirectoryCallsForNothingButALockFileInAWorktreeDoes() {
    let found = targets([
      "/repos/demo/.git/refs/remotes/origin/main.lock", "/repos/demo/Cargo.lock",
    ])

    #expect(found.projectsWithGitChanges.isEmpty)
    #expect(Set(found.fileChangesByWorktree.keys) == [main.id])
  }

  @Test func aDroppedBatchNamingTheGitDirectoryItselfIsTheWholeProjects() {
    #expect(targets(["/repos/demo/.git"]).projectsWithGitChanges == [project.id])
  }

  @Test func aChangeInAWorktreeIsTheDeepestWorktreeHoldingIt() {
    #expect(
      Set(targets(["/repos/demo/.worktrees/side/src"]).fileChangesByWorktree.keys) == [nested.id]
    )
    #expect(Set(targets(["/repos/demo/src"]).fileChangesByWorktree.keys) == [main.id])
  }

  @Test func aChangeOutsideEveryProjectCallsForNothing() {
    let found = targets(["/elsewhere/src"])

    #expect(found.projectsWithGitChanges.isEmpty)
    #expect(found.fileChangesByWorktree.isEmpty)
    #expect(found.projectsWithSharedSettingsChanges.isEmpty)
  }

  /// A submodule added as a project has its git directory inside the outer
  /// one's; a dictionary's order picked between them.
  @Test func aChangeInAGitDirectoryInsideAnotherIsTheInnerProjects() {
    for index in 0..<24 {
      let outer = Project(path: URL(fileURLWithPath: "/repos/outer\(index)"))
      let innerCommon = URL(fileURLWithPath: "/repos/outer\(index)/.git/modules/sub")
      let inner = Project(path: innerCommon)

      let found = FileChangeTargets(
        changed: [innerCommon.appending(path: "refs")],
        projects: [outer, inner],
        gitDirectories: [
          outer.id: URL(fileURLWithPath: "/repos/outer\(index)/.git"), inner.id: innerCommon,
        ],
        worktrees: [],
        themesDirectory: themes,
      )

      #expect(found.projectsWithGitChanges == [inner.id])
    }
  }

  @Test func aChangeToTheSharedSettingsFileIsItsProjects() {
    #expect(
      targets(["/repos/demo/.multishell.json"]).projectsWithSharedSettingsChanges == [project.id]
    )
    #expect(targets(["/repos/demo/README.md"]).projectsWithSharedSettingsChanges.isEmpty)
  }

  @Test func anEditInAWorktreeInsideABareRepositoryIsThatWorktrees() {
    let bareProject = Project(path: URL(fileURLWithPath: "/repos/repo.git"))
    let bare = Worktree(path: bareProject.path, projectID: bareProject.id, head: "", isBare: true)
    let inside = Worktree(
      path: URL(fileURLWithPath: "/repos/repo.git/main"),
      projectID: bareProject.id,
      head: "abc",
      branch: "main",
    )

    let found = FileChangeTargets(
      changed: [URL(fileURLWithPath: "/repos/repo.git/main/src")],
      projects: [bareProject],
      gitDirectories: [bareProject.id: bareProject.path],
      worktrees: [bare, inside],
      themesDirectory: themes,
    )

    #expect(Set(found.fileChangesByWorktree.keys) == [inside.id])
    #expect(found.projectsWithGitChanges.isEmpty)
  }

  @Test func aChangeUnderTheThemesFolderIsAThemeChangeAndNoProjects() {
    let found = targets(["/support/themes/dusk.json"])

    #expect(found.hasThemeChanges)
    #expect(found.projectsWithGitDirectoryChanges.isEmpty)
    #expect(!targets(["/repos/demo/README.md"]).hasThemeChanges)
  }

  @Test func anyChangeInTheGitDirectoryScratchIncludedMayMoveItsRecords() {
    let found = targets(["/repos/demo/.git/objects/ab", "/repos/demo/.git/index.lock"])

    #expect(found.projectsWithGitChanges.isEmpty)
    #expect(found.projectsWithGitDirectoryChanges == [project.id])
    #expect(targets(["/repos/demo/README.md"]).projectsWithGitDirectoryChanges.isEmpty)
  }

  @Test func theMainWorktreesOwnConfigIsTheWholeProjects() {
    #expect(targets(["/repos/demo/.git/config.worktree"]).projectsWithGitChanges == [project.id])
  }

  @Test func aNestedGitignoreChangingIsItsWorktreesIgnoreRuleChange() {
    let found = targets(["/repos/demo/packages/p/.gitignore", "/repos/demo/src"])

    #expect(found.worktreesWithIgnoreRuleChanges == [main.id])
    #expect(Set(found.fileChangesByWorktree.keys) == [main.id])
  }

  /// An embedded repository, or a submodule never absorbed, keeps its `.git`
  /// in the worktree, and the outer status's recursion writes a cookie there.
  @Test func gitsScratchInAGitDirectoryInsideAWorktreeCallsForNothingButTheGitEntryItselfDoes() {
    let scratch = targets([
      "/repos/demo/sub/.git/fsmonitor--daemon/cookies", "/repos/demo/sub/.git/index.lock",
      "/repos/demo/sub/.git/fsmonitor--daemon.ipc",
    ])
    let gitEntry = targets(["/repos/demo/sub/.git"])

    #expect(scratch.fileChangesByWorktree.isEmpty)
    #expect(Set(gitEntry.fileChangesByWorktree.keys) == [main.id])
  }
}
