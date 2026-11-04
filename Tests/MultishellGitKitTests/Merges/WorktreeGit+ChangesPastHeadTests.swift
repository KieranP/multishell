import Foundation
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitChangesPastHeadTests {
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
    let rebased = try await fixture.head(of: fixture.project.path)

    let project = fixture.project
    #expect(
      await git.hasChanges(
        on: work,
        pastHead: later,
        ownRemoteBranch: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == false
    )
    #expect(
      await git.hasChanges(
        on: work,
        pastHead: rebased,
        ownRemoteBranch: "origin/feat",
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
    let amended = try await fixture.head(of: fixture.project.path)

    let project = fixture.project
    #expect(
      await git.hasChanges(
        on: later,
        pastHead: work,
        ownRemoteBranch: "origin/feat",
        ownBranch: "main",
        in: project,
      )
        == true
    )
    #expect(
      await git.hasChanges(
        on: amended,
        pastHead: work,
        ownRemoteBranch: "origin/feat",
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
    let tip = try await fixture.head(of: fixture.project.path)

    #expect(
      await git.hasChanges(
        on: tip,
        pastHead: mergedHead,
        ownRemoteBranch: "origin/feat",
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
        ownRemoteBranch: "origin/feat",
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
        ownRemoteBranch: "origin/feat",
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
        ownRemoteBranch: "origin/feat",
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
    let tip = try await fixture.head(of: fixture.project.path)
    let unknown = String(repeating: "1", count: 40)

    #expect(
      await git.hasChanges(
        on: tip,
        pastHead: unknown,
        ownRemoteBranch: "origin/feat",
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
    try await fixture.commit(file, file: file, content: content)
    return try await fixture.head(of: fixture.project.path)
  }
}
