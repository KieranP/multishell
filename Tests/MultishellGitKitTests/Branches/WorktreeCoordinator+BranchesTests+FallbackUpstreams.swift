import Foundation
import TestSupport
import Testing

@testable import MultishellCore
@testable import MultishellGitKit

extension WorktreeCoordinatorBranchesTests {
  @Test func aBranchFollowingTheTrunkBesideARemoteBranchOfItsNameFallsBackOnTheTrunk()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let repository = fixture.project.path
    _ = try await fixture.runner.run(["push", "-q", "origin", "main:feat"], in: repository)
    _ = try await fixture.runner.run(
      ["branch", "-q", "--track", "feat", "origin/main"],
      in: repository,
    )
    let main = try await fixture.tip(of: "main")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "origin", branch: "feat", tip: main))
    #expect(
      scan.fallbackUpstreams["feat"]
        == .some(BranchUpstream(remote: "origin", branch: "main", tip: main))
    )
  }

  @Test func aBranchFollowingNothingBesideARemoteBranchOfItsNameFallsBackOnNone() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let repository = fixture.project.path
    _ = try await fixture.runner.run(["push", "-q", "origin", "main:feat"], in: repository)
    _ = try await fixture.runner.run(
      ["branch", "-q", "--no-track", "feat", "main"],
      in: repository,
    )

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"]?.branch == "feat")
    #expect(scan.fallbackUpstreams["feat"] == .some(nil))
  }

  @Test func aBranchTrackingItsOwnNameHasNothingToFallBackOn() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    _ = try await fixture.runner.run(
      ["push", "-q", "-u", "origin", "feat:feat"],
      in: fixture.project.path,
    )

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"]?.branch == "feat")
    #expect(scan.fallbackUpstreams["feat"] == nil)
  }

  @Test func aBranchPushingToAForkOfItsNameFallsBackOnTheBranchItTracks() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    let repository = fixture.project.path
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "feat:feat"], in: repository)
    try await fixture.addFork()
    _ = try await fixture.runner.run(["push", "-q", "fork", "feat"], in: repository)
    _ = try await fixture.runner.run(["config", "branch.feat.pushRemote", "fork"], in: repository)
    let tip = try await fixture.tip(of: "feat")

    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )

    #expect(scan.upstreams?["feat"] == BranchUpstream(remote: "fork", branch: "feat", tip: tip))
    #expect(
      scan.fallbackUpstreams["feat"]
        == .some(BranchUpstream(remote: "origin", branch: "feat", tip: tip))
    )
  }

  @Test func aScanReadWithoutTheUpstreamAtomsHasNothingToFallBackOn() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *remotename*) exit 129 ;;
      esac
      printf 'refs/heads/feat\\tabc\\trefs/remotes/origin/main\\t\\t\\n'
      printf 'refs/remotes/origin/feat\\tdef\\t\\t\\t\\n'
      """
    )
    defer { fake.tearDown() }

    let scan = try #require(
      await fake.coordinator.scanBranches(
        of: Project(path: fake.directory),
        defaultBranchOverride: nil,
      )
    )

    #expect(scan.fallbackUpstreams.isEmpty)
  }
}
