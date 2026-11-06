import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelStatusReadsTests {
  private static func plantNeverPushedStatus(
    on worktree: Worktree,
    in harness: GitHarness,
  ) async throws -> WorktreeStatus {
    try await waitUntil { harness.model.pendingBranchScans.isEmpty }
    try await harness.statusReadsSettle(worktree)
    var planted = WorktreeStatus()
    planted.branch = worktree.branch
    planted.changedFiles = 99
    harness.model.statuses[worktree.id] = planted
    return planted
  }

  @Test func aBranchNeverPushedShowsItsCommitsPastTheDefaultBranchAsAhead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feature = try await harness.createWorktree(onBranch: "feature")
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "work"],
      in: feature.path,
    )
    await harness.model.refreshBranchScan(of: harness.project)

    await harness.model.refreshStatuses()

    #expect(harness.model.statuses[feature.id]?.upstream == nil)
    #expect(harness.model.statuses[feature.id]?.ahead == 1)
  }

  @Test func aRowOffTheSidebarIsNotReadAgainWhenTheDefaultBranchResolves() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let side = try await harness.createWorktree(onBranch: "side")
    harness.model.select(try #require(harness.worktree(onBranch: "main")))
    let planted = try await Self.plantNeverPushedStatus(on: side, in: harness)
    harness.model.setExpanded(false, for: harness.project)
    harness.model.defaultBranchScans = [:]

    await harness.model.refreshBranchScan(of: harness.project)
    try await harness.statusReadsSettle(side)

    #expect(harness.model.defaultBranch(of: harness.project) != nil)
    #expect(harness.model.statuses[side.id] == planted)
  }

  @Test func aDefaultBranchWhoseTipAloneMovedReadsNoRowAgain() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let side = try await harness.createWorktree(onBranch: "side")
    harness.model.select(side)
    let planted = try await Self.plantNeverPushedStatus(on: side, in: harness)
    let base = try #require(harness.model.defaultBranch(of: harness.project))
    let earlierTip = DefaultBranch(
      shortName: base.shortName,
      nameWithoutRemote: base.nameWithoutRemote,
      tip: "0000000",
      fullName: base.fullName,
    )
    harness.model.defaultBranchScans[harness.project.id] = .found(earlierTip)

    await harness.model.refreshBranchScan(of: harness.project)
    try await harness.statusReadsSettle(side)

    #expect(harness.model.defaultBranch(of: harness.project) == base)
    #expect(harness.model.statuses[side.id] == planted)
  }

  @Test func aShownRowNotYetReadIsReadOnceTheDefaultBranchResolves() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let side = try await harness.createWorktree(onBranch: "side")
    harness.model.select(side)
    _ = try await Self.plantNeverPushedStatus(on: side, in: harness)
    harness.clearStatuses()
    harness.model.defaultBranchScans = [:]

    await harness.model.refreshBranchScan(of: harness.project)

    try await waitUntil { harness.model.statuses[side.id] != nil }
    #expect(harness.model.statuses[side.id]?.branch == "side")
  }

  @Test func aStatusReadBeforeTheFirstBranchScanIsReadAgainOnceTheDefaultBranchResolves()
    async throws
  {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    try await harness.addOrigin()
    let feature = try await harness.createWorktree(onBranch: "feature")
    _ = try await harness.git.run(
      ["commit", "-q", "--allow-empty", "-m", "work"],
      in: feature.path,
    )
    try await waitUntil { harness.model.pendingBranchScans.isEmpty }
    try await harness.statusReadsSettle(feature)
    harness.model.defaultBranchScans = [:]
    await harness.model.refreshStatuses()
    try #require(harness.model.statuses[feature.id]?.ahead == 0)

    await harness.model.refreshBranchScan(of: harness.project)

    try await waitUntil { harness.model.statuses[feature.id]?.ahead == 1 }
    #expect(harness.model.statuses[feature.id]?.ahead == 1)
  }
}
