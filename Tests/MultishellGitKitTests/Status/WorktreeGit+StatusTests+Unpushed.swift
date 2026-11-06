import Foundation
import MultishellCore
import TestSupport
import Testing

@testable import MultishellGitKit

extension WorktreeGitStatusTests {
  private static func base(of fixture: RepositoryFixture) async throws -> DefaultBranch {
    let refs = await fixture.git.branchRefs(fixture.project)?.refs ?? []
    return try #require(DefaultBranch.resolve(from: refs, override: nil))
  }

  private static func commitWork(in path: URL, of fixture: RepositoryFixture) async throws {
    try await TestRepository.commit(
      "work \(UUID().uuidString)",
      files: ["work-\(UUID().uuidString).txt": "work\n"],
      in: path,
      using: fixture.runner,
    )
  }

  @Test func aBranchNeverPushedCountsItsCommitsBeyondTheBaseAsAhead() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await Self.commitWork(in: path, of: fixture)
    let feature = try await fixture.worktree(onBranch: "feature")
    let base = try await Self.base(of: fixture)

    let status = try await fixture.git.status(of: feature, against: base)

    #expect(base.shortName == "origin/main")
    #expect(status.upstream == nil)
    #expect(status.ahead == 1)
    #expect(!status.isCleanAndInSync)
  }

  @Test func aDirtyBranchNeverPushedStillCountsItsCommitsBeyondTheBase() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await Self.commitWork(in: path, of: fixture)
    try "changed\n".write(
      to: path.appendingPathComponent("README.md"),
      atomically: true,
      encoding: .utf8,
    )
    let feature = try await fixture.worktree(onBranch: "feature")

    let status = try await fixture.git.status(
      of: feature,
      against: try await Self.base(of: fixture),
    )

    #expect(status.isDirty)
    #expect(status.ahead == 1)
  }

  @Test func aBranchPushedWithoutAnUpstreamCountsOnlyCommitsNoRemoteHas() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await Self.commitWork(in: path, of: fixture)
    _ = try await fixture.runner.run(["push", "-q", "origin", "feature"], in: path)
    let feature = try await fixture.worktree(onBranch: "feature")
    let base = try await Self.base(of: fixture)

    let pushed = try await fixture.git.status(of: feature, against: base)
    try await Self.commitWork(in: path, of: fixture)
    let oneMore = try await fixture.git.status(of: feature, against: base)

    #expect(pushed.upstream == nil)
    #expect(pushed.ahead == 0)
    #expect(oneMore.ahead == 1)
  }

  @Test func aFailedCountPastTheBaseFailsTheReadRatherThanReportingNoneAhead() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## feature\\0' ;;
        *rev-list*) exit 128 ;;
      esac
      """
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    await #expect(throws: (any Error).self) {
      try await WorktreeGit(runner: fake.runner).status(
        of: worktree,
        against: .sample("main", remote: "origin"),
      )
    }
  }

  @Test func aBranchWithNoCommitsYetIsNotCountedPastTheBase() async throws {
    let fake = try FakeGit.make(
      """
      case "$*" in
        *status*) printf '## No commits yet on feature\\0' ;;
        *rev-list*) exit 128 ;;
      esac
      """,
      loggingCalls: true,
    )
    defer { fake.tearDown() }
    let worktree = Worktree(path: fake.directory, projectID: fake.directory.path, head: "abc")

    let status = try await WorktreeGit(runner: fake.runner).status(
      of: worktree,
      against: .sample("main", remote: "origin"),
    )

    #expect(status.ahead == 0)
    #expect(!FakeGit.calls(in: fake.directory).contains { $0.contains("rev-list") })
  }

  @Test func aRepositoryWithNoRemoteCountsAheadOfItsLocalTrunk() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await Self.commitWork(in: path, of: fixture)
    let feature = try await fixture.worktree(onBranch: "feature")
    let base = try await Self.base(of: fixture)

    let status = try await fixture.git.status(of: feature, against: base)

    #expect(base.shortName == "main")
    #expect(status.ahead == 1)
  }

  @Test func aBranchWithAnUpstreamCountsAheadOfItsUpstreamNotTheBase() async throws {
    let fixture = try await RepositoryFixture.make()
    defer { fixture.tearDown() }
    try await fixture.addOrigin()
    let path = try await fixture.addWorktree(onNewBranch: "feature")
    try await Self.commitWork(in: path, of: fixture)
    _ = try await fixture.runner.run(["push", "-q", "-u", "origin", "feature"], in: path)
    try await Self.commitWork(in: path, of: fixture)
    let feature = try await fixture.worktree(onBranch: "feature")

    let status = try await fixture.git.status(
      of: feature,
      against: try await Self.base(of: fixture),
    )

    #expect(status.upstream == "origin/feature")
    #expect(status.ahead == 1)
  }
}
