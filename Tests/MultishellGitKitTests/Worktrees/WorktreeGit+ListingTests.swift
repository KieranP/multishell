import Foundation
import MultishellProcess
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitListingTests {
  /// At the descriptor limit a child's output used to vanish and the list
  /// came back empty; taken as a result it emptied the project of its tabs.
  @Test func anEmptyWorktreeListIsAnErrorNotAResult() async throws {
    let fake = try FakeGit.make("exit 0")
    defer { fake.tearDown() }
    let project = Project(path: fake.directory)

    await #expect(throws: ProcessFailure.self) {
      try await WorktreeGit(runner: fake.runner).list(project)
    }
  }

  @Test func aListOfTheMainWorktreeAloneIsAResult() async throws {
    // `-z`, as the real one is asked: NUL where the newline was.
    let fake = try FakeGit.make(
      "printf 'worktree /repos/demo\\0HEAD 1111111\\0branch refs/heads/main\\0'")
    defer { fake.tearDown() }

    let listed = try await WorktreeGit(runner: fake.runner).list(Project(path: fake.directory))

    #expect(listed.map(\.branch) == ["main"])
  }

  @Test func aGitThatRefusesTheNulFormIsAskedForTheNewlineOne() async throws {
    let fake = try FakeGit.make(
      """
      case " $* " in *" -z "*) echo "error: unknown switch \\`z'" >&2; exit 129 ;; esac
      printf 'worktree /repos/demo\\nHEAD 1111111\\nbranch refs/heads/main\\n\\n'
      """)
    defer { fake.tearDown() }
    let worktreeGit = WorktreeGit(runner: fake.runner)

    let listed = try await worktreeGit.list(Project(path: fake.directory))
    let main = try await worktreeGit.mainWorktreePath(containing: fake.directory)

    #expect(listed.map(\.branch) == ["main"])
    #expect(main.path == "/repos/demo")
  }

  /// git records no creation date, so this is the birth time of the directory that
  /// `git worktree add` made, and the second worktree must not read as the older.
  @Test func listStampsEachWorktreeWithItsDirectorysCreationDate() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let project = fixture.project
    let coordinator = fixture.coordinator
    try await coordinator.createThenRunPostCreateHook(
      branch: "first", in: project, settings: fixture.worktreeSettings)
    try await coordinator.createThenRunPostCreateHook(
      branch: "second", in: project, settings: fixture.worktreeSettings)

    let listed = try await WorktreeGit(runner: fixture.runner).list(project)
    let dates = try listed.map { try #require($0.createdAt, "no date for \($0.name)") }
    let byBranch = Dictionary(uniqueKeysWithValues: zip(listed.map(\.name), dates))

    #expect(byBranch["first"]! <= byBranch["second"]!)
    #expect(byBranch["main"]! <= byBranch["first"]!, "the repository predates its worktrees")
  }

  /// git's own docs call the non-`-z` porcelain unsafe for paths with
  /// newlines: the second half reads as another attribute line.
  @Test func aWorktreePathHoldingANewlineIsStillOneWorktree() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let odd = fixture.root.appendingPathComponent("my\nrepo", isDirectory: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "-b", "odd", odd.path], in: fixture.project.path)

    let worktrees = try await WorktreeGit(runner: fixture.runner).list(fixture.project)

    #expect(worktrees.count == 2, "got \(worktrees.map(\.path.path))")
    let listed = worktrees.first { !$0.isPrimary }
    #expect(listed?.path.lastPathComponent == "my\nrepo")
    #expect(listed?.branch == "odd")
  }

  @Test func aSubdirectoryAndALinkedWorktreeResolveToTheMainWorktree() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let linked = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "side", in: fixture.project, settings: fixture.worktreeSettings)
    let subdirectory = fixture.project.path.appendingPathComponent("Sources", isDirectory: true)
    try FileManager.default.createDirectory(at: subdirectory, withIntermediateDirectories: true)

    func root(_ url: URL) async throws -> String {
      try await fixture.coordinator.git.mainWorktreePath(containing: url).resolvingSymlinksInPath()
        .path
    }
    let main = fixture.project.path.resolvingSymlinksInPath().path

    #expect(try await root(fixture.project.path) == main)
    #expect(try await root(subdirectory) == main)
    #expect(try await root(linked) == main, "a linked worktree is the same project")
  }

  @Test func aDirectoryOutsideAnyRepositoryIsAnError() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    await #expect(throws: (any Error).self) {
      try await fixture.coordinator.git.mainWorktreePath(containing: fixture.root)
    }
  }

  @Test func theListReflectsCreateAndRemove() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "a", in: fixture.project, settings: fixture.worktreeSettings)
    try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "b", in: fixture.project, settings: fixture.worktreeSettings)
    var listed = try await fixture.coordinator.git.list(fixture.project)
    #expect(listed.map(\.branch) == ["main", "a", "b"])
    #expect(listed[0].isPrimary && !listed[1].isPrimary)
    #expect(listed.allSatisfy { $0.projectID == fixture.project.id })

    try await fixture.coordinator.removeUnlinking(listed[1], in: fixture.project)
    listed = try await fixture.coordinator.git.list(fixture.project)
    #expect(listed.map(\.branch) == ["main", "b"])
  }
}
