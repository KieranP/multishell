import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// These dates come off the ref list the merge reads need anyway, so they cost no process
/// of their own.
@Suite(.serialized)
struct WorktreeCoordinatorBranchesTests {
  @Test func eachLocalBranchCarriesItsLastCommitTime() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commitOnBranch("feat", "later", file: "feat.txt", content: "a\n")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))
    let main = try #require(scan.lastCommitDates["main"])
    let feat = try #require(scan.lastCommitDates["feat"])

    #expect(main <= feat, "feat was committed to after main was left behind")
    #expect(abs(feat.timeIntervalSinceNow) < 300, "a real commit time, not the epoch")
    #expect(scan.lastCommitDates["origin/main"] == nil, "local branches only")
  }

  /// `git worktree list` gives `feat/tabs`, and the ref list must key it the same, not as
  /// `refs/heads/feat/tabs` or with the first component dropped.
  @Test func aBranchWithSlashesIsKeyedTheWayAWorktreeNamesIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.createThenRunPostCreate(
      branch: "feat/tabs", in: fixture.project,
      settings: fixture.worktreeSettings)

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)
    let worktree = try #require(
      listed.first { $0.path.standardizedFileURL == path.standardizedFileURL })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))

    #expect(worktree.branch == "feat/tabs")
    #expect(worktree.branch.flatMap { scan.lastCommitDates[$0] } != nil, "the lookup finds it")
  }

  /// A worktree's branch is what the app looks the date up by, so a
  /// detached checkout has none rather than borrowing another branch's.
  @Test func aDetachedWorktreeHasNoBranchToDate() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let head = try await fixture.head(of: fixture.project.path)
    let path = fixture.root.appendingPathComponent("detached", isDirectory: true)
    _ = try await fixture.runner.run(
      ["worktree", "add", "-q", "--detach", path.path, head], in: fixture.project.path)

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)
    let detached = try #require(listed.first { $0.path.lastPathComponent == "detached" })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))

    #expect(detached.branch == nil)
    #expect(Set(scan.lastCommitDates.keys) == ["main"], "no date filed under a name it lacks")
    #expect(detached.createdAt != nil, "the directory still has a creation date")
  }

  @Test func anOverrideNamingNoBranchBadgesNothingAndKeepsTheDates() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let missing = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: "nowhere"))
    #expect(missing.mergeInputs == nil)
    #expect(missing.lastCommitDates["main"] != nil, "the dates come back with no base to measure")
  }
}
