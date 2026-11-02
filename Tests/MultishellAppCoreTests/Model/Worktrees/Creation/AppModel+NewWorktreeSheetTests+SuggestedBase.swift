import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

extension AppModelNewWorktreeSheetTests {
  private func suggestedStartPoint(in harness: GitHarness) async throws -> String? {
    var draft = NewWorktreeDraft(projectID: harness.project.id)
    draft.beginLoading()
    let read = try #require(await harness.model.newWorktreeBranches(of: harness.project))
    draft.finishLoading(harness.project.id, with: read, checkedOut: [])
    return draft.startPoint
  }

  private func run(_ arguments: [String], in harness: GitHarness) async throws {
    _ = try await harness.git.run(arguments, in: harness.project.path)
  }

  @Test func theBaseStartsOnTheDefaultBranchWhileTheCheckoutIsOnAnother() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(try await suggestedStartPoint(in: harness) == "main")
  }

  @Test func aSheetOpenedBeforeTheFirstBranchScanStillStartsOnTheDefaultBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    harness.model.defaultBranchScans[harness.project.id] = nil

    #expect(try await suggestedStartPoint(in: harness) == "main")
  }

  @Test func withNoDefaultBranchTheBaseStartsOnTheCheckoutsBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await run(["branch", "-m", "main", "trunk"], in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.defaultBranch(of: harness.project) == nil)
    #expect(try await suggestedStartPoint(in: harness) == "trunk")
  }

  @Test func withAnOriginTheBaseIsTheLocalDefaultBranchRatherThanTheRemoteOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(harness.model.defaultBranch(of: harness.project)?.shortName == "origin/main")
    #expect(try await suggestedStartPoint(in: harness) == "main")
  }

  @Test func withNoLocalCopyTheBaseIsTheRemoteDefaultBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    try await run(["branch", "-q", "-D", "main"], in: harness)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(try await suggestedStartPoint(in: harness) == "origin/main")
  }

  @Test func theProjectsDefaultBranchSettingIsTheBase() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await run(["branch", "release"], in: harness)
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    harness.model.setSettings(ProjectSettings(defaultBranch: "release"), for: harness.project)
    await harness.model.refreshBranchScan(of: harness.project)

    #expect(try await suggestedStartPoint(in: harness) == "release")
  }

  @Test func aDefaultBranchDeletedSinceTheLastScanIsNeverTheBase() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    await harness.model.refreshBranchScan(of: harness.project)
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    try await run(["branch", "-q", "-D", "main"], in: harness)

    #expect(harness.model.defaultBranch(of: harness.project)?.shortName == "main")
    #expect(try await suggestedStartPoint(in: harness) == "upgrade-deps")
  }

  @Test func aWorktreeMadeFromTheSuggestedBaseStartsAtTheDefaultBranchAndTracksNothing()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    try await run(["checkout", "-q", "-b", "upgrade-deps"], in: harness)
    try await run(["commit", "-q", "--allow-empty", "-m", "deps"], in: harness)
    await harness.model.refreshBranchScan(of: harness.project)
    let mainTip = try await harness.git.run(["rev-parse", "main"], in: harness.project.path)

    let created = try #require(
      await harness.model.createWorktree(
        branch: "fix",
        basedOn: try await suggestedStartPoint(in: harness),
        createsBranch: true,
        in: harness.project,
      )
    )

    let head = try await harness.git.run(["rev-parse", "HEAD"], in: created.path)
    #expect(head == mainTip)
    let upstream = try? await harness.git.run(
      ["rev-parse", "--abbrev-ref", "fix@{upstream}"],
      in: harness.project.path,
    )
    #expect(upstream == nil)
  }
}
