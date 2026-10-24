import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

@Suite
struct WorktreeGitRenameMaterialTests {
  private static func material(
    in fixture: RepositoryFixture,
    diffByteLimit: Int = WorktreeGit.renameDiffByteLimit,
  ) async throws -> RenameMaterial? {
    let git = WorktreeGit(runner: fixture.runner)
    let refs = await git.branchRefs(fixture.project) ?? []
    let base = try #require(DefaultBranch.resolve(from: refs, override: nil))
    return try await git.renameMaterial(
      inRepositoryAt: fixture.project.path,
      since: base,
      diffByteLimit: diffByteLimit,
    )
  }

  @Test func commitsAndStagedChangesAreReadButUnstagedAndNewFilesAreNot() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("seed", file: "a.txt", content: "one\n")
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try await fixture.commit("Add billing export", file: "export.txt", content: "csv\n")
    try fixture.write("staged\n", to: "staged.txt")
    _ = try await fixture.runner.run(["add", "staged.txt"], in: fixture.project.path)
    try fixture.write("one\nunstaged\n", to: "a.txt")
    try fixture.write("untracked\n", to: "new.txt")

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.subjects == ["Add billing export"])
    #expect(material.diffstat.contains("export.txt") && material.diffstat.contains("staged.txt"))
    #expect(material.diff.contains("+csv") && material.diff.contains("+staged"))
    #expect(!material.diffstat.contains("a.txt") && !material.diff.contains("unstaged"))
    #expect(!material.diffstat.contains("new.txt"))
    #expect(!material.isEmpty)
  }

  @Test func aBranchWithNothingCommittedOrStagedHasNothingToNameFrom() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try fixture.write("unstaged\n", to: "a.txt")

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.isEmpty)
    #expect(material.subjects.isEmpty && material.diffstat.isEmpty && material.diff.isEmpty)
  }

  @Test func aLongDiffIsCutAtALineWithinItsLimitAndSaysSo() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    let lines = (1...400).map { "line \($0)" }.joined(separator: "\n") + "\n"
    try await fixture.commit("Big", file: "big.txt", content: lines)

    let material = try #require(try await Self.material(in: fixture, diffByteLimit: 500))

    #expect(material.isDiffCut)
    #expect(material.diff.utf8.count <= 500)
    #expect(material.diff.hasSuffix("\n"))
    #expect(!material.diff.contains("line 400"))
  }

  @Test func aPathSpellingAFileHeaderLeavesTheStatWhole() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try fixture.write("x\n", to: "diff --git x.txt")
    try fixture.write("b\n", to: "b.txt")
    _ = try await fixture.runner.run(["add", "."], in: fixture.project.path)

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.diffstat.contains("2 files changed"))
    #expect(material.diff.hasPrefix("diff --git a/"))
  }

  @Test func aDiffWithinItsLimitIsWhole() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try await fixture.commit("Small", file: "small.txt", content: "one\n")

    let material = try #require(try await Self.material(in: fixture))

    #expect(!material.isDiffCut)
    #expect(material.diff.contains("+one"))
  }

  @Test func aBranchSharingNoHistoryWithItsBaseHasNoMaterialAtAll() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(
      ["checkout", "-q", "--orphan", "fresh"],
      in: fixture.project.path,
    )
    try await fixture.commit("Start over", file: "new.txt", content: "new\n")

    #expect(try await Self.material(in: fixture) == nil)
  }

  @Test func mergeCommitsAreNotSubjects() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try await fixture.commit("Add export", file: "export.txt", content: "csv\n")
    _ = try await fixture.runner.run(["checkout", "-q", "main"], in: fixture.project.path)
    try await fixture.commit("Main moves", file: "main.txt", content: "m\n")
    _ = try await fixture.runner.run(["checkout", "-q", "work"], in: fixture.project.path)
    _ = try await fixture.runner.run(
      ["merge", "-q", "--no-edit", "-m", "Merge main into work", "main"],
      in: fixture.project.path,
    )

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.subjects == ["Add export"])
  }

  @Test func aBranchWithNoCommitYetIsReadFromItsStagedFiles() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(
      ["checkout", "-q", "--orphan", "fresh"],
      in: fixture.project.path,
    )
    _ = try await fixture.runner.run(["rm", "-rq", "--cached", "."], in: fixture.project.path)
    try fixture.write("staged\n", to: "first.txt")
    _ = try await fixture.runner.run(["add", "first.txt"], in: fixture.project.path)

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.subjects.isEmpty)
    #expect(material.diffstat.contains("first.txt"))
    #expect(material.diff.contains("+staged"))
  }

  @Test func aNulInATextDiffIsTakenOutSoThePromptIsNotCutAtIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    _ = try await fixture.runner.run(["checkout", "-q", "-b", "work"], in: fixture.project.path)
    try fixture.write(String(repeating: "a", count: 9_000) + "\u{0}tail\n", to: "late-nul.txt")
    _ = try await fixture.runner.run(["add", "late-nul.txt"], in: fixture.project.path)

    let material = try #require(try await Self.material(in: fixture))

    #expect(material.diff.contains("tail"))
    #expect(!material.diff.contains("\u{0}"))
  }
}
