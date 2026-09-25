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

  @Test func aRepositoryIsRecognisedAndItsParentIsNot() async throws {
    let repo = try await RepositoryFixture.make()
    defer { repo.tearDown() }
    #expect(await repo.coordinator.git.isRepository(repo.project.path))
    #expect(await repo.coordinator.git.isRepository(repo.root) == false)
  }
}
