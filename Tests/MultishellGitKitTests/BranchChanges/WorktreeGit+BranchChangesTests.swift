import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct WorktreeGitBranchChangesTests {
  private static func base(of fixture: RepositoryFixture) async throws -> DefaultBranch {
    let refs = await WorktreeGit(runner: fixture.runner).branchRefs(fixture.project) ?? []
    return try #require(DefaultBranch.resolve(from: refs, override: nil))
  }

  private static func branchChanges(
    in fixture: RepositoryFixture,
    at tree: URL? = nil,
  ) async throws -> BranchChanges {
    let git = WorktreeGit(runner: fixture.runner)
    let path = tree ?? fixture.project.path
    let status = try await git.status(
      inRepositoryAt: path,
      counting: .stagedAndUnstaged,
      diffAlgorithm: .histogram,
    )
    return try #require(
      await git.branchChanges(
        inRepositoryAt: path,
        since: try await base(of: fixture),
        status: status,
        diffAlgorithm: .histogram,
      )
    )
  }

  @Test func committedUncommittedAndNewFilesAllCountSinceTheBranchLeftItsBase() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "one\n")
    let base = try await Self.base(of: fixture)
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try await fixture.commit("work", file: "b.txt", content: "b\nb\n")
    try fixture.write("one\ntwo\n", to: "a.txt")
    try fixture.write("new\n", to: "c.txt")

    let changes = try await Self.branchChanges(in: fixture)

    #expect(changes.baseName == base.shortName)
    #expect(changes.mergeBase == base.tip)
    #expect(
      Set(changes.changes) == [
        StatusChange(
          path: "a.txt",
          kind: .modified,
          lines: .counted(insertions: 1, deletions: 0),
        ),
        StatusChange(path: "b.txt", kind: .added, lines: .counted(insertions: 2, deletions: 0)),
        StatusChange(path: "c.txt", kind: .added, lines: .counted(insertions: 1, deletions: 0)),
      ]
    )
    #expect(changes.insertions == 4 && changes.deletions == 0)
  }

  @Test func aFileTheBranchDeletedIsListedDeleted() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "gone.txt", content: "a\nb\n")
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    _ = try await fixture.runner.run(["rm", "-q", "gone.txt"], in: fixture.project.path)
    _ = try await fixture.runner.run(["commit", "-q", "-m", "drop"], in: fixture.project.path)

    let changes = try await Self.branchChanges(in: fixture)

    #expect(
      changes.changes == [
        StatusChange(
          path: "gone.txt",
          kind: .deleted,
          lines: .counted(insertions: 0, deletions: 2),
        )
      ]
    )
  }

  @Test func aBaseThatMovedOnCountsOnlyWhatTheBranchDid() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let tree = try await fixture.addWorktree(onNewBranch: "work")
    try await fixture.commit("later on main", file: "main.txt", content: "main\n")
    try "work\n".write(to: tree.appending(path: "work.txt"), atomically: true, encoding: .utf8)

    let changes = try await Self.branchChanges(in: fixture, at: tree)

    #expect(changes.changes.map(\.path) == ["work.txt"])
  }

  @Test func aBranchSharingNoHistoryWithTheBaseHasNoMergeBaseAndNoChanges() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let base = try await Self.base(of: fixture)
    _ = try await fixture.runner.run(
      ["checkout", "-q", "--orphan", "alone"],
      in: fixture.project.path,
    )
    try await fixture.commit("alone", file: "alone.txt", content: "alone\n")

    let changes = try await Self.branchChanges(in: fixture)
    let mergeBase = try await WorktreeGit(runner: fixture.runner).mergeBase(
      with: base,
      inRepositoryAt: fixture.project.path,
    )

    #expect(changes.mergeBase == nil && changes.changes == [])
    #expect(mergeBase == nil)
  }

  @Test func aNewFileCommittedSinceTheStatusReadIsCountedOnce() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let base = try await Self.base(of: fixture)
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try fixture.write("a\nb\nc\n", to: "new.txt")
    let staleStatus = try await git.status(
      inRepositoryAt: fixture.project.path,
      counting: .stagedAndUnstaged,
      diffAlgorithm: .histogram,
    )
    try await fixture.commit("add", file: "new.txt", content: "a\nb\nc\n")

    let changes = try #require(
      await git.branchChanges(
        inRepositoryAt: fixture.project.path,
        since: base,
        status: staleStatus,
        diffAlgorithm: .histogram,
      )
    )

    #expect(changes.changes.map(\.path) == ["new.txt"])
    #expect(changes.insertions == 3)
  }

  @Test func aBranchWithNoCommitsYetSharesNoHistoryWithTheBase() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await Self.base(of: fixture)
    _ = try await fixture.runner.run(
      ["checkout", "-q", "--orphan", "unborn"],
      in: fixture.project.path,
    )

    let changes = try await Self.branchChanges(in: fixture)

    #expect(changes.mergeBase == nil && changes.changes == [])
  }

  @Test func aMergeBaseBeyondAShallowClonesCutIsAFailedReadNotAnUnsharedHistory() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commitOnBranch("feature", file: "f.txt", content: "f\n")
    try await fixture.commit("later", file: "m.txt", content: "m\n")
    let clone = fixture.root.appending(path: "shallow")
    _ = try await fixture.runner.run(
      [
        "clone", "-q", "--depth", "1", "--no-single-branch", "-b", "feature",
        "file://" + fixture.project.path.path, clone.path,
      ],
      in: fixture.root,
    )
    let git = WorktreeGit(runner: fixture.runner)
    let refs = await git.branchRefs(Project(path: clone)) ?? []
    let base = try #require(DefaultBranch.resolve(from: refs, override: nil))

    await #expect(throws: (any Error).self) {
      _ = try await git.mergeBase(with: base, inRepositoryAt: clone)
    }
  }

  @Test func aMergeBaseGitCouldNotReadIsAFailedReadNotAnUnsharedHistory() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *merge-base*) exit 128 ;;
        *rev-parse*) exit 128 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let base = DefaultBranch(
      shortName: "main",
      nameWithoutRemote: "main",
      tip: "abc",
      fullName: "refs/heads/main",
    )

    let changes = await WorktreeGit(runner: fake.runner).branchChanges(
      inRepositoryAt: fake.directory,
      since: base,
      status: nil,
      diffAlgorithm: .histogram,
    )

    #expect(changes == nil)
  }

  @Test func aFileTakenOutOfTheIndexButLeftOnDiskIsListedBothWays() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "kept.txt", content: "a\nb\n")
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    _ = try await fixture.runner.run(
      ["rm", "-q", "--cached", "kept.txt"],
      in: fixture.project.path,
    )

    let changes = try await Self.branchChanges(in: fixture)

    #expect(
      Set(changes.changes) == [
        StatusChange(
          path: "kept.txt",
          kind: .deleted,
          lines: .counted(insertions: 0, deletions: 2),
        ),
        StatusChange(
          path: "kept.txt",
          kind: .added,
          lines: .counted(insertions: 2, deletions: 0),
        ),
      ]
    )
  }
}
