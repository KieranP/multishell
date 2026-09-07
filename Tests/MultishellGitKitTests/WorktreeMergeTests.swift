import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// The merge check against real repositories: the three ways a branch lands,
/// and the branches it must not claim have landed.
@Suite(.serialized)
struct WorktreeMergeTests {
  /// The fixture with a bare `origin` beside it, so a branch can be pushed
  /// and then deleted on the remote the way a merge does.
  private func withRemote(_ fixture: RepositoryFixture) async throws {
    let origin = fixture.root.appendingPathComponent("origin.git", isDirectory: true)
    _ = try await fixture.git.run(
      ["clone", "-q", "--bare", fixture.project.path.path, origin.path], in: fixture.root)
    _ = try await fixture.git.run(
      ["remote", "add", "origin", origin.path], in: fixture.project.path)
    _ = try await fixture.git.run(["fetch", "-q", "origin"], in: fixture.project.path)
  }

  private func scan(_ fixture: RepositoryFixture, override: String? = nil) async throws -> MergeScan
  {
    let scan = await fixture.coordinator.mergeScan(of: fixture.project, defaultBranch: override)
    return try #require(scan)
  }

  @Test func aBranchMergedWithAMergeCommitIsFoundByAncestry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "main")
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .merged(.ancestor, into: "main"))
  }

  @Test func aBranchWhosePatchesAreAlreadyOnTheBaseIsFoundByCherry() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "rebased"], in: path)
    try await fixture.commit("work", file: "rebased.txt", content: "a\n")
    let commit = try await fixture.head(of: path)
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    // Main moves first, so the cherry-pick lands on a different parent and
    // cannot come out as the very same commit object.
    try await fixture.commit("elsewhere", file: "other.txt", content: "b\n")
    // What a rebase-merge leaves: the same patch, a different commit.
    _ = try await fixture.git.run(["cherry-pick", commit], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["rebased"], in: fixture.project, scan: scan)
    #expect(states["rebased"] == .merged(.patchEquivalent, into: "main"))
    // Ancestry alone would have missed it.
    let merged = await WorktreeService(git: fixture.git).mergedBranches(
      into: "main", in: fixture.project)
    #expect(merged?.contains("rebased") == false)
  }

  @Test func aBranchWhoseUpstreamWasDeletedOnTheRemoteReadsAsMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)

    _ = try await fixture.git.run(["checkout", "-q", "-b", "squashed"], in: path)
    try await fixture.commit("work", file: "squashed.txt", content: "a\n")
    _ = try await fixture.git.run(["push", "-q", "-u", "origin", "squashed"], in: path)
    // The merge on the forge squashes the commits and deletes the branch.
    _ = try await fixture.git.run(["push", "-q", "origin", "--delete", "squashed"], in: path)
    _ = try await fixture.git.run(["fetch", "-q", "--prune", "origin"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.base.ref == "origin/main")
    #expect(scan.upstreamIsGone("squashed"))
    let states = await fixture.coordinator.mergeStates(
      of: ["squashed"], in: fixture.project, scan: scan)
    #expect(states["squashed"] == .merged(.upstreamGone, into: "origin/main"))
  }

  /// `git worktree add -b` cuts the branch at the trunk's own tip, which
  /// makes it an ancestor of the trunk before a line has been written in
  /// it. Ancestry alone would badge it.
  @Test func aBranchJustCutForANewWorktreeIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await fixture.commit("second", file: "b.txt", content: "b\n")
    let tree = fixture.root.appendingPathComponent("trees/fresh", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "fresh", tree.path, "HEAD"], in: path)

    let scan = try await scan(fixture)
    // git itself calls it merged, which is the whole trap.
    let merged = await WorktreeService(git: fixture.git).mergedBranches(
      into: scan.base.ref, in: fixture.project)
    #expect(merged?.contains("fresh") == true)

    let states = await fixture.coordinator.mergeStates(
      of: ["fresh"], in: fixture.project, scan: scan)
    #expect(states["fresh"] == .unmerged)
  }

  /// The same branch once it has been committed to and fast-forwarded in:
  /// its tip is the trunk's tip again, but its reflog says it moved.
  @Test func aBranchFastForwardedIntoTheTrunkIsStillMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    let tree = fixture.root.appendingPathComponent("trees/ff", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "-b", "ff", tree.path, "HEAD"], in: path)
    try "a\n".write(to: tree.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
    _ = try await fixture.git.run(["add", "."], in: tree)
    _ = try await fixture.git.run(["commit", "-q", "-m", "work"], in: tree)
    _ = try await fixture.git.run(["merge", "-q", "--ff-only", "ff"], in: path)

    let scan = try await scan(fixture)
    #expect(scan.tip(of: "ff") == scan.base.tip, "indistinguishable from a fresh branch by tips")
    let states = await fixture.coordinator.mergeStates(of: ["ff"], in: fixture.project, scan: scan)
    #expect(states["ff"] == .merged(.ancestor, into: "main"))
  }

  @Test func aBranchWithWorkOfItsOwnIsNotMerged() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .unmerged)
  }

  @Test func aBranchThatLandedAndThenMovedAgainIsUnmergedOnceMore() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path

    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("work", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)
    _ = try await fixture.git.run(["merge", "-q", "--no-ff", "-m", "merge", "feat"], in: path)
    _ = try await fixture.git.run(["checkout", "-q", "feat"], in: path)
    try await fixture.commit("more", file: "feat.txt", content: "b\n")

    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(
      of: ["feat"], in: fixture.project, scan: scan)
    #expect(states["feat"] == .unmerged)
  }

  @Test func theDefaultBranchIsTheRemotesWhereThereIsOneAndTheUsersWhereTheySaid()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    try await withRemote(fixture)
    _ = try await fixture.git.run(["checkout", "-q", "-b", "develop"], in: path)
    try await fixture.commit("dev", file: "dev.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    // The clone recorded origin/HEAD, and the remote wins over a local main
    // that a pull has not caught up with.
    let detected = try await scan(fixture)
    #expect(detected.base.ref == "origin/main")
    #expect(detected.base.branch == "main")

    // The user's own name, which exists only locally.
    let overridden = try await scan(fixture, override: "develop")
    #expect(overridden.base.ref == "develop")

    // A name that is nowhere: no base, so nothing is badged.
    let missing = await fixture.coordinator.mergeScan(
      of: fixture.project, defaultBranch: "nowhere")
    #expect(missing == nil)
  }

  @Test func aScanOfNoBranchesAsksGitNothingAndAnswersNothing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let scan = try await scan(fixture)
    let states = await fixture.coordinator.mergeStates(of: [], in: fixture.project, scan: scan)
    #expect(states.isEmpty)
  }

  @Test func onlyALinkedWorktreeOnABranchOfItsOwnCanBeBadged() {
    let main = Worktree(
      path: URL(fileURLWithPath: "/r"), projectID: "/r", head: "a",
      branch: "main", isPrimary: true)
    let trunk = Worktree(
      path: URL(fileURLWithPath: "/t/main"), projectID: "/r", head: "a",
      branch: "main")
    let feat = Worktree(
      path: URL(fileURLWithPath: "/t/feat"), projectID: "/r", head: "a",
      branch: "feat")
    let detached = Worktree(path: URL(fileURLWithPath: "/t/d"), projectID: "/r", head: "abc1234")
    let bare = Worktree(
      path: URL(fileURLWithPath: "/r.git"), projectID: "/r", head: "a",
      isBare: true)

    #expect(WorktreeMergeState.applies(to: feat, base: "main"))
    // The main worktree cannot be removed, so "safe to remove" cannot apply.
    #expect(!WorktreeMergeState.applies(to: main, base: "main"))
    // The trunk's own checkout in a bare layout: not merged into itself.
    #expect(!WorktreeMergeState.applies(to: trunk, base: "main"))
    #expect(!WorktreeMergeState.applies(to: detached, base: "main"))
    #expect(!WorktreeMergeState.applies(to: bare, base: "main"))
  }
}
