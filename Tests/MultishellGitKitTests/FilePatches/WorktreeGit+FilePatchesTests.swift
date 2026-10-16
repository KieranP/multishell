import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite
struct WorktreeGitFilePatchesTests {
  @Test func aStagedEditShowsInBothPatchesAndALaterOneOnDiskAlone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "one\n")
    try fixture.write("two\n", to: "a.txt")
    _ = try await fixture.runner.run(["add", "a.txt"], in: fixture.project.path)
    try fixture.write("three\n", to: "a.txt")

    let patches = try #require(
      await WorktreeGit(runner: fixture.runner).patches(
        of: "a.txt",
        in: fixture.project.path,
        diffAlgorithm: .histogram,
      )
    )

    let onDisk = String(decoding: patches.onDisk, as: UTF8.self)
    let staged = String(decoding: patches.staged, as: UTF8.self)
    #expect(onDisk.contains("-one") && onDisk.contains("+three"))
    #expect(staged.contains("-one") && staged.contains("+two") && !staged.contains("three"))
  }

  @Test func aUsersSuppressBlankEmptyLeavesABlankContextLineInThePatch() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "a\n\nb\n")
    _ = try await fixture.runner.run(
      ["config", "diff.suppressBlankEmpty", "true"],
      in: fixture.project.path,
    )
    try fixture.write("a\n\nB\n", to: "a.txt")

    let patches = try #require(
      await WorktreeGit(runner: fixture.runner).patches(
        of: "a.txt",
        in: fixture.project.path,
        diffAlgorithm: .histogram,
      )
    )

    #expect(String(decoding: patches.onDisk, as: UTF8.self).contains("\n a\n \n-b\n"))
  }
}
