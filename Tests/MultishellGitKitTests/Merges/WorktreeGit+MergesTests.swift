import Foundation
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitMergesTests {
  @Test func aBranchsRenameIsNotOnABaseThatOnlyAddedTheNewName() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("old name", file: "A.txt", content: "same\n")
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "feat"], in: path)
    _ = try await fixture.runner.run(["mv", "A.txt", "B.txt"], in: path)
    _ = try await fixture.runner.run(["commit", "-q", "-m", "rename"], in: path)
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)
    try await fixture.commit("new name too", file: "B.txt", content: "same\n")

    #expect(
      await fixture.git.changesAreOnBase("feat", against: "main", in: fixture.project) == false
    )
  }

  @Test func aBranchsSubmoduleBumpCountsWhereGitmodulesIgnoresIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let first = try await fixture.head(of: path)
    try await fixture.commit(
      "submodule ignored",
      file: ".gitmodules",
      content: "[submodule \"sub\"]\n\tpath = sub\n\turl = ./sub\n\tignore = all\n",
    )
    let second = try await fixture.head(of: path)
    try await setGitlink(to: first, in: fixture, message: "sub")
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "feat"], in: path)
    try await setGitlink(to: second, in: fixture, message: "bump sub")
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: path)
    try await fixture.commit("base moves on", file: "b.txt", content: "b\n")

    #expect(
      await fixture.git.changesAreOnBase("feat", against: "main", in: fixture.project) == false
    )
  }

  private func setGitlink(
    to commit: String,
    in fixture: RepositoryFixture,
    message: String,
  ) async throws {
    let path = fixture.project.path
    _ = try await fixture.runner.run(
      ["update-index", "--add", "--cacheinfo", "160000,\(commit),sub"],
      in: path,
    )
    _ = try await fixture.runner.run(["commit", "-q", "-m", message], in: path)
  }
}
