import Foundation
import MultishellCore
import Testing

@testable import MultishellGitKit

@Suite(.serialized)
struct WorktreeGitRemotesTests {
  @Test func aRepositoryWithNoRemoteListsNoneRatherThanFailing() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }

    #expect(await fixture.git.remotes(fixture.project) == [])
  }

  @Test func publishingPushesTheBranchAndMakesItTrackTheRemoteOne() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")

    try await fixture.git.publish(
      "feat",
      as: "feat",
      to: "origin",
      in: fixture.project.path,
    )

    let remotes = try #require(await fixture.git.remotes(fixture.project))
    #expect(remotes.map(\.name) == ["origin"])
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )
    #expect(scan.upstreams?["feat"]?.remote == "origin")
    #expect(scan.upstreams?["feat"]?.branch == "feat")
    #expect(scan.upstreams?["feat"]?.tip != nil, "the remote has the branch now")
    #expect(try await followed(by: "feat", in: fixture) == "origin/feat")
  }

  @Test func publishingABranchThatFollowsTheTrunkOnTheSameRemoteMakesItTrackItsOwn()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    try await follow("origin/main", from: "feat", in: fixture)

    try await fixture.git.publish(
      "feat",
      as: "feat",
      to: "origin",
      in: fixture.project.path,
    )

    #expect(try await followed(by: "feat", in: fixture) == "origin/feat")
  }

  @Test func aBranchWithNoPushRemoteConfiguredNamesNoneThoughItFollowsOne() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.addFork()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    try await follow("origin/main", from: "feat", in: fixture)
    let git = fixture.git
    let path = fixture.project.path

    #expect(await git.configuredPushRemote(ofBranch: "feat", in: path) == nil)
    _ = try await fixture.runner.run(["config", "remote.pushDefault", "fork"], in: path)
    #expect(await git.configuredPushRemote(ofBranch: "feat", in: path) == "fork")
    _ = try await fixture.runner.run(["config", "branch.feat.pushRemote", "origin"], in: path)
    #expect(await git.configuredPushRemote(ofBranch: "feat", in: path) == "origin")
  }

  @Test func publishingToTheBranchsOwnPushRemoteKeepsWhatItFollows() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.addFork()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    try await follow("origin/main", from: "feat", in: fixture)
    _ = try await fixture.runner.run(
      ["config", "branch.feat.pushRemote", "fork"],
      in: fixture.project.path,
    )

    try await fixture.git.publish(
      "feat",
      as: "feat",
      to: "fork",
      in: fixture.project.path,
    )

    #expect(try await followed(by: "feat", in: fixture) == "origin/main")
    let scan = try #require(
      await fixture.coordinator.scanBranches(of: fixture.project, defaultBranchOverride: nil)
    )
    #expect(scan.upstreams?["feat"]?.remote == "fork", "found where its pushes go")
  }

  @Test func publishingToAnotherRemoteWithNoPushRemoteNamedMakesItTrackWhatWasPushed()
    async throws
  {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    try await fixture.addFork()
    try await fixture.commitOnBranch("feat", file: "feat.txt", content: "a\n")
    try await follow("origin/main", from: "feat", in: fixture)

    try await fixture.git.publish(
      "feat",
      as: "feat",
      to: "fork",
      in: fixture.project.path,
    )

    #expect(try await followed(by: "feat", in: fixture) == "fork/feat")
  }

  private func follow(
    _ upstream: String,
    from branch: String,
    in fixture: RepositoryFixture,
  )
    async throws
  {
    _ = try await fixture.runner.run(
      ["branch", "-q", "--set-upstream-to=\(upstream)", branch],
      in: fixture.project.path,
    )
  }

  private func followed(by branch: String, in fixture: RepositoryFixture) async throws -> String {
    try await fixture.runner.run(
      ["rev-parse", "--abbrev-ref", "\(branch)@{upstream}"],
      in: fixture.project.path,
    )
    .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
