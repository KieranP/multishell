import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

/// These dates come off the ref list the merge reads need anyway, so they cost no process
/// of their own.
@Suite(.serialized)
struct WorktreeCoordinatorBranchesTests {
  @Test func eachLocalBranchCarriesItsLastCommitTime() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n", message: "later")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )
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
    let path = try await fixture.coordinator.createThenRunPostCreateHook(
      branch: "feat/tabs",
      in: fixture.project,
      settings: fixture.worktreeSettings,
    )

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)
    let worktree = try #require(
      listed.first { $0.path.standardizedFileURL == path.standardizedFileURL }
    )
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

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
      ["worktree", "add", "-q", "--detach", path.path, head],
      in: fixture.project.path,
    )

    let listed = try await WorktreeGit(runner: fixture.runner).list(fixture.project)
    let detached = try #require(listed.first { $0.path.lastPathComponent == "detached" })
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(detached.branch == nil)
    #expect(Set(scan.lastCommitDates.keys) == ["main"], "no date filed under a name it lacks")
    #expect(detached.createdAt != nil, "the directory still has a creation date")
  }

  @Test func aPushedBranchNamesItsRemoteItsNameThereAndWhereThatPoints() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(
      ["push", "-q", "-u", "origin", "feat:shared/feat"],
      in: fixture.project.path,
    )
    let pushed = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(
      scan.upstreams?["feat"]
        == BranchUpstream(remote: "origin", branch: "shared/feat", tip: pushed)
    )
  }

  @Test func aBranchPushingToAnotherRemoteIsPublishedThereUnderItsOwnName() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let repository = fixture.project.path
    let fork = fixture.root.appendingPathComponent("fork.git")
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "feat"], in: repository)
    _ = try await fixture.runner.run(
      ["clone", "-q", "--bare", repository.path, fork.path],
      in: fixture.root,
    )
    _ = try await fixture.runner.run(["remote", "add", "fork", fork.path], in: repository)
    _ = try await fixture.runner.run(["push", "-q", "fork", "feat"], in: repository)
    _ = try await fixture.runner.run(["config", "branch.feat.pushRemote", "fork"], in: repository)
    let tip = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "fork", branch: "feat", tip: tip))
  }

  @Test func aBranchFollowingItsOwnNameIsPublishedThereThoughItsPushRemoteLacksIt() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let repository = fixture.project.path
    let fork = fixture.root.appendingPathComponent("fork.git")
    _ = try await fixture.runner.run(["init", "-q", "--bare", fork.path], in: fixture.root)
    _ = try await fixture.runner.run(["remote", "add", "fork", fork.path], in: repository)
    _ = try await fixture.runner.run(["config", "remote.pushDefault", "fork"], in: repository)
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "feat"], in: repository)
    let tip = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "origin", branch: "feat", tip: tip))
  }

  @Test func aBranchPushedWithoutTrackingIsPublishedUnderItsNameOnTheRemote() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(["push", "-q", "origin", "feat"], in: fixture.project.path)
    let tip = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "origin", branch: "feat", tip: tip))
  }

  @Test func aBranchFollowingTheTrunkButPushedUnderItsOwnNameIsPublishedThere() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let repository = fixture.project.path
    _ = try await fixture.runner.run(["push", "-q", "origin", "feat"], in: repository)
    _ = try await fixture.runner.run(
      ["branch", "-q", "--set-upstream-to", "origin/main", "feat"],
      in: repository,
    )
    let tip = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "origin", branch: "feat", tip: tip))
  }

  @Test func aScanReadWithoutTheUpstreamAtomsLeavesUpstreamsUnknown() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *remotename*) exit 129 ;;
      esac
      printf 'refs/heads/feat\\tabc\\trefs/remotes/origin/feat\\t\\t\\n'
      """
    )
    defer { fake.tearDown() }

    let scan = try #require(
      await fake.coordinator.scanBranches(
        of: Project(path: fake.directory),
        defaultBranchOverride: nil,
      )
    )

    #expect(scan.upstreams == nil)
  }

  @Test func anUpstreamWhoseRefHasGoneHasNoTip() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let repository = fixture.project.path
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "feat"], in: repository)
    _ = try await fixture.runner.run(["push", "-q", "origin", "--delete", "feat"], in: repository)

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "origin", branch: "feat", tip: nil))
  }

  @Test func anOverrideNamingNoBranchBadgesNothingAndKeepsTheDates() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let missing = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: "nowhere")
    )
    #expect(missing.mergeInputs == nil)
    #expect(missing.lastCommitDates["main"] != nil, "the dates come back with no base to measure")
  }

  @Test func theDefaultBranchIsTheRemotesWhereThereIsOneAndTheUsersWhereTheySaid()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("develop", file: "dev.txt", content: "a\n", message: "dev")

    let detected = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)?
        .mergeInputs
    )
    #expect(
      detected.defaultBranch.shortName == "origin/main",
      "the remote wins over a local main a pull has not caught up with",
    )
    #expect(detected.defaultBranch.nameWithoutRemote == "main")

    let overridden = try #require(
      await fixture.coordinator.scanBranches(
        of: fixture.project,
        defaultBranchOverride: "develop",
      )?
      .mergeInputs
    )
    #expect(overridden.defaultBranch.shortName == "develop")
  }
}
