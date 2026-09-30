import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeGitBranchesTests {
  @Test func currentAndLocalBranchesComeFromGit() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.runner.run(["branch", "feature"], in: repo.project.path)

    #expect(try await repo.coordinator.git.currentBranch(repo.project) == "main")
    let names = try #require(await repo.coordinator.git.branchNames(repo.project))
    #expect(names.local.sorted() == ["feature", "main"])
  }

  @Test func remoteBranchesComeFromRefsRemotesWithoutHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let upstream = repo.project
    _ = try await repo.runner.run(["branch", "feature"], in: upstream.path)
    let clone = repo.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await repo.runner.run(["clone", "-q", upstream.path.path, clone.path], in: repo.root)

    let names = try #require(
      await WorktreeGit(runner: repo.runner).branchNames(Project(path: clone)))
    #expect(names.remote.sorted() == ["origin/feature", "origin/main"])
  }

  @Test func aTagSharingABranchNameLeavesThePickableNamesBare() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let upstream = repo.project
    _ = try await repo.runner.run(["branch", "dup"], in: upstream.path)
    let clone = repo.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await repo.runner.run(["clone", "-q", upstream.path.path, clone.path], in: repo.root)
    _ = try await repo.runner.run(["branch", "dup"], in: clone)
    _ = try await repo.runner.run(["tag", "dup"], in: clone)
    _ = try await repo.runner.run(["tag", "origin/dup"], in: clone)

    let names = try #require(
      await WorktreeGit(runner: repo.runner).branchNames(Project(path: clone)))
    #expect(names.local.sorted() == ["dup", "main"])
    #expect(names.remote.sorted() == ["origin/dup", "origin/main"])
  }
}
