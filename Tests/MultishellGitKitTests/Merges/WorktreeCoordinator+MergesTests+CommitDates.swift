import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

/// These dates come off the ref list the merge scan already reads, so they cost no process
/// of their own.
extension WorktreeCoordinatorMergesTests {
  @Test func eachLocalBranchCarriesItsLastCommitTime() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = fixture.project.path
    _ = try await fixture.git.run(["checkout", "-q", "-b", "feat"], in: path)
    try await fixture.commit("later", file: "feat.txt", content: "a\n")
    _ = try await fixture.git.run(["checkout", "-q", "main"], in: path)

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))
    let main = try #require(scan.lastCommits["main"])
    let feat = try #require(scan.lastCommits["feat"])

    #expect(main <= feat, "feat was committed to after main was left behind")
    #expect(abs(feat.timeIntervalSinceNow) < 300, "a real commit time, not the epoch")
    #expect(scan.lastCommits["origin/main"] == nil, "local branches only")
  }

  /// `git worktree list` gives `feat/tabs`, and the ref list must key it the same, not as
  /// `refs/heads/feat/tabs` or with the first component dropped.
  @Test func aBranchWithSlashesIsKeyedTheWayAWorktreeNamesIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.coordinator.create(
      branch: "feat/tabs", in: fixture.project,
      settings: fixture.worktreeSettings)

    let listed = try await WorktreeGit(runner: fixture.git).list(fixture.project)
    let worktree = try #require(
      listed.first { $0.path.standardizedFileURL == path.standardizedFileURL })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))

    #expect(worktree.branch == "feat/tabs")
    #expect(worktree.branch.flatMap { scan.lastCommits[$0] } != nil, "the lookup finds it")
  }

  /// A worktree's branch is what the app looks the date up by, so a
  /// detached checkout has none rather than borrowing another branch's.
  @Test func aDetachedWorktreeHasNoBranchToDate() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let head = try await fixture.head(of: fixture.project.path)
    let path = fixture.root.appendingPathComponent("detached", isDirectory: true)
    _ = try await fixture.git.run(
      ["worktree", "add", "-q", "--detach", path.path, head], in: fixture.project.path)

    let listed = try await WorktreeGit(runner: fixture.git).list(fixture.project)
    let detached = try #require(listed.first { $0.path.lastPathComponent == "detached" })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil))

    #expect(detached.branch == nil)
    #expect(detached.branch.flatMap { scan.lastCommits[$0] } == nil)
    #expect(detached.createdAt != nil, "the directory still has a creation date")
  }
}
