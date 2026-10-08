import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeGitBranchesTests {
  @Test func currentAndLocalBranchesComeFromGit() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["branch", "feature"], in: fixture.project.path)

    #expect(try await fixture.coordinator.git.currentBranch(fixture.project) == "main")
    let names = try #require(await fixture.coordinator.git.branchNames(fixture.project))
    #expect(names.local.sorted() == ["feature", "main"])
  }

  @Test func remoteBranchesComeFromRefsRemotesWithoutHEAD() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let upstream = fixture.project
    _ = try await fixture.runner.run(["branch", "feature"], in: upstream.path)
    let clone = fixture.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await fixture.runner.run(
      ["clone", "-q", upstream.path.path, clone.path], in: fixture.root)

    let names = try #require(
      await WorktreeGit(runner: fixture.runner).branchNames(Project(path: clone)))
    #expect(names.remote.sorted() == ["origin/feature", "origin/main"])
  }

  @Test func aTagSharingABranchNameLeavesThePickableNamesBare() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let upstream = fixture.project
    _ = try await fixture.runner.run(["branch", "dup"], in: upstream.path)
    let clone = fixture.root.appendingPathComponent("clone", isDirectory: true)
    _ = try await fixture.runner.run(
      ["clone", "-q", upstream.path.path, clone.path], in: fixture.root)
    _ = try await fixture.runner.run(["branch", "dup"], in: clone)
    _ = try await fixture.runner.run(["tag", "dup"], in: clone)
    _ = try await fixture.runner.run(["tag", "origin/dup"], in: clone)

    let names = try #require(
      await WorktreeGit(runner: fixture.runner).branchNames(Project(path: clone)))
    #expect(names.local.sorted() == ["dup", "main"])
    #expect(names.remote.sorted() == ["origin/dup", "origin/main"])
  }
}
