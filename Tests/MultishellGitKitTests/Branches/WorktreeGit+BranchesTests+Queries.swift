import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeGitBranchesTests {
  @Test func currentAndLocalBranchesComeFromGit() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    _ = try await repo.git.run(["branch", "feature"], in: repo.project.path)

    #expect(try await repo.coordinator.git.currentBranch(repo.project) == "main")
    #expect(
      try await repo.coordinator.git.localBranches(repo.project).sorted() == ["feature", "main"])
  }

  @Test func remoteBranchesComeFromRefsRemotesWithoutHEAD() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    let upstream = repo.project
    _ = try await repo.git.run(["branch", "feature"], in: upstream.path)
    let clone = repo.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await repo.git.run(["clone", "-q", upstream.path.path, clone.path], in: repo.root)

    let branches = try await WorktreeGit(runner: repo.git).remoteBranches(Project(path: clone))
    #expect(branches.sorted() == ["origin/feature", "origin/main"])
  }
}
