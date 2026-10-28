import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitBranchesTests {
  /// The ref read carries both the sidebar's commit dates and the badges' tips, and a git that
  /// cannot give the first must still give the second.
  @Test func aGitTooOldForTheDateAtomStillAnswersWithTheRest() async throws {
    // Fails any query naming committerdate, as git does for an unknown
    // format atom, and answers the rest.
    let fake = try FakeGit.make(
      """
      case "$*" in
        *committerdate*) echo "fatal: unknown field name: committerdate:unix" >&2; exit 128 ;;
      esac
      printf 'refs/heads/main\\t111\\t\\t\\t\\n'
      """
    )
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeGit(runner: fake.runner).branchRefs(Project(path: fake.directory))?.refs
    )

    #expect(refs.map(\.fullName) == ["refs/heads/main"], "the badges still have their tips")
    #expect(refs.first?.tip == "111")
    #expect(refs.first?.committedAt == nil, "the order loses its dates, and only those")
  }

  @Test func aGitThatAnswersIsAskedOnce() async throws {
    let fake = try FakeGit.make(
      #"printf 'refs/heads/main\t111\t\t\t\t1700000000\n'"#,
      loggingCalls: true,
    )
    defer { fake.tearDown() }

    let refs = try #require(
      await WorktreeGit(runner: fake.runner).branchRefs(Project(path: fake.directory))?.refs
    )

    #expect(refs.first?.committedAt == Date(timeIntervalSince1970: 1_700_000_000))
    #expect(FakeGit.calls(in: fake.directory).count == 1)
  }

  @Test func aTipBehindItsHeadOrRebasedOntoAnotherBaseHasNoChangesPastIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let work = try await commit(file: "work.txt", content: "a\n", in: fixture)
    let later = try await commit(file: "later.txt", content: "b\n", in: fixture)
    _ = try await fixture.runner.run(
      ["checkout", "-q", "-b", "rebased", "HEAD~2"],
      in: fixture.project.path,
    )
    _ = try await commit(file: "base.txt", content: "c\n", in: fixture)
    _ = try await fixture.runner.run(["cherry-pick", work], in: fixture.project.path)
    let rebased = try await head(in: fixture)

    let project = fixture.project
    #expect(
      await git.hasChanges(
        on: work,
        pastHead: later,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == false
    )
    #expect(
      await git.hasChanges(
        on: work,
        pastHead: rebased,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      ) == false
    )
  }

  @Test func aTipWithACommitOrAnAmendTheHeadLacksHasChangesPastIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let work = try await commit(file: "work.txt", content: "a\n", in: fixture)
    let later = try await commit(file: "later.txt", content: "b\n", in: fixture)
    _ = try await fixture.runner.run(["reset", "-q", "--hard", work], in: fixture.project.path)
    try "a, reworked\n".write(
      to: fixture.project.path.appendingPathComponent("work.txt"),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await fixture.runner.run(
      ["commit", "-q", "-a", "--amend", "-m", "reworked"],
      in: fixture.project.path,
    )
    let amended = try await head(in: fixture)

    let project = fixture.project
    #expect(
      await git.hasChanges(
        on: later,
        pastHead: work,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == true
    )
    #expect(
      await git.hasChanges(
        on: amended,
        pastHead: work,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      ) == true
    )
  }

  @Test func aTipThatMergedARemoteTrunkAfterItsSquashHasNoChangesOfItsOwn() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let path = fixture.project.path
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "feat"], in: path)
    let mergedHead = try await commit(file: "work.txt", content: "a\n", in: fixture)
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)
    _ = try await commit(file: "other.txt", content: "b\n", in: fixture)
    let squashed = try await commit(file: "work.txt", content: "a\n", in: fixture)
    _ = try await fixture.runner.run(
      ["update-ref", "refs/remotes/origin/main", squashed],
      in: path,
    )
    _ = try await fixture.runner.run(["checkout", "-q", "feat"], in: path)
    _ = try await fixture.runner.run(["merge", "-q", "--no-edit", "origin/main"], in: path)
    let tip = try await head(in: fixture)

    #expect(
      await git.hasChanges(
        on: tip,
        pastHead: mergedHead,
        ownRemote: "origin/feat",
        ownBranch: "feat",
        in: fixture.project,
      )
        == false
    )
  }

  @Test func aCommitOnTheBranchsOwnRemoteBranchIsStillItsOwn() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let work = try await commit(file: "work.txt", content: "a\n", in: fixture)
    let later = try await commit(file: "later.txt", content: "b\n", in: fixture)
    let path = fixture.project.path
    _ = try await fixture.runner.run(["update-ref", "refs/remotes/origin/feat", later], in: path)

    #expect(
      await git.hasChanges(
        on: later,
        pastHead: work,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: fixture.project,
      )
        == true
    )
  }

  @Test func aCommitOnlyItsOwnLocalBranchHoldsIsItsOwnUntilAnotherBranchHoldsIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let work = try await commit(file: "work.txt", content: "a\n", in: fixture)
    let later = try await commit(file: "later.txt", content: "b\n", in: fixture)
    let project = fixture.project

    #expect(
      await git.hasChanges(
        on: later,
        pastHead: work,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == true
    )
    _ = try await fixture.runner.run(["branch", "-q", "child", later], in: project.path)
    #expect(
      await git.hasChanges(
        on: later,
        pastHead: work,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == false
    )
  }

  @Test func aHeadTheRepositoryLacksGetsNoAnswer() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let git = WorktreeGit(runner: fixture.runner)
    let tip = try await head(in: fixture)
    let unknown = String(repeating: "1", count: 40)

    #expect(
      await git.hasChanges(
        on: tip,
        pastHead: unknown,
        ownRemote: "origin/feat",
        ownBranch: "main",
        in: fixture.project,
      ) == nil
    )
  }

  private func commit(
    file: String,
    content: String,
    in fixture: RepositoryFixture,
  ) async throws
    -> String
  {
    try content.write(
      to: fixture.project.path.appendingPathComponent(file),
      atomically: true,
      encoding: .utf8,
    )
    _ = try await fixture.runner.run(["add", file], in: fixture.project.path)
    _ = try await fixture.runner.run(["commit", "-q", "-m", file], in: fixture.project.path)
    return try await head(in: fixture)
  }

  private func head(in fixture: RepositoryFixture) async throws -> String {
    try await fixture.runner.run(["rev-parse", "HEAD"], in: fixture.project.path)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
