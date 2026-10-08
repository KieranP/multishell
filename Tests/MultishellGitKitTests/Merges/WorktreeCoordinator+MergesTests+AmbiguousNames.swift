import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

extension WorktreeCoordinatorMergesTests {
  /// git reads a bare name shared with a path as "both revision and filename" and fails the
  /// read, leaving the branch as never written in; see Docs/design/merged-branch.md.
  @Test func aBranchNamedAfterADirectoryIsStillJudgedByItsReflog() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("a directory to collide with", file: "docs/notes.md", content: "a\n")

    try await fixture.commitOnBranch("docs", file: "docs/one.md", content: "one\n")
    _ = try await fixture.runner.run(
      ["merge", "-q", "--no-ff", "-m", "merge docs", "docs"], in: path)

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, inputs: inputs)

    #expect(states["docs"] == .merged(.ancestor, into: "main"))
  }

  /// A tag of the branch's name makes `%(refname:short)` answer `heads/x`,
  /// matching no worktree's branch, and a bare name reach the tag instead.
  @Test func aTagSharingABranchsNameChangesNeitherTheListNorTheVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    // The tag sits on the first commit, so judging by it would read the
    // branch as holding nothing of its own.
    _ = try await fixture.runner.run(["tag", "release"], in: path)
    try await fixture.commitOnBranch("release", file: "one.md", content: "one\n")
    // By refname, or git merges the tag: the ambiguity this is about reaches
    // the setup as readily as the reads.
    _ = try await fixture.runner.run(
      ["merge", "-q", "--no-ff", "-m", "merge release", "refs/heads/release"], in: path)

    let worktreeGit = WorktreeGit(runner: fixture.runner)
    let merged = await worktreeGit.mergedBranches(into: "main", in: fixture.project)
    #expect(merged?.contains("release") == true, "got \(merged ?? [])")

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["release"], in: fixture.project, inputs: inputs)
    #expect(states["release"] == .merged(.ancestor, into: "main"))
  }

  @Test func aTagNamedLikeTheLocalBaseDecidesNoVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(["tag", "main", "feat"], in: path)

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)

    #expect(states["feat"] == .unmerged)
  }

  @Test func aTagNamedLikeTheRemoteBaseDecidesNoVerdict() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(["tag", "origin/main", "feat"], in: path)

    let inputs = try await mergeInputs(fixture)
    #expect(inputs.defaultBranch.shortName == "origin/main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, inputs: inputs)

    #expect(states["feat"] == .unmerged)
  }

  /// The same collision on the content read: the two-name form of `git diff` takes the
  /// branch for a path, and the squash-merged branch loses its badge.
  @Test func aSquashedBranchNamedAfterADirectoryStillReadsAsMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commit("a directory to collide with", file: "docs/notes.md", content: "a\n")
    try await fixture.addOrigin()

    try await fixture.pushThenSquashMergeOnTheRemote(
      "docs", work: [("docs/one.md", "one\n"), ("docs/two.md", "two\n")])

    let inputs = try await mergeInputs(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["docs"], in: fixture.project, inputs: inputs)

    #expect(states["docs"] == .merged(.upstreamGone, into: "origin/main"))
  }
}
