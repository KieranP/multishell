import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelBranchScansTests {
  @Test func aScanThatFindsNothingMovedStartsNoBranchRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }
    try await harness.statusReadsSettle(feature)
    try await waitUntil { !harness.model.branchChangesReads.isRunning(feature.id) }
    let git = try #require(harness.model.coordinator?.git)
    git.runLog.setRecording(true)
    defer { git.runLog.setRecording(false) }
    _ = git.runLog.drain()

    await harness.model.refreshBranchScan(of: harness.project)
    harness.model.scheduleBranchChangesRead(of: feature.id)
    try await waitUntil { !harness.model.branchChangesReads.isRunning(feature.id) }

    let mergeBases = git.runLog.drain().finishedRuns.filter { $0.command.hasPrefix("merge-base") }
    #expect(mergeBases.count == 1, "the read asked for here, and none from the scan")
  }

  @Test func aFileTabUnderBranchReadsAgainOnceItsProjectsBaseResolves() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["README.md": "hello\ncommitted\n"],
      in: feature.path,
      using: harness.git,
    )
    for scan in harness.model.pendingBranchScans.values { scan.cancel() }
    harness.model.pendingBranchScans = [:]
    harness.model.defaultBranchScans[harness.project.id] = nil
    harness.model.setChangeScope(.branch)
    let tab = try #require(harness.model.openFileTab("README.md", in: feature))
    let headRows = try #require(try await harness.rowsArrive(in: tab.id))
    #expect(!headRows.hasLineChanges, "no base yet, so counted from HEAD")

    await harness.model.refreshBranchScan(of: harness.project)

    let sinceBase = FileLineCounts(insertions: 1, deletions: 0)
    try await waitUntil { harness.lineCounts(of: tab) == sinceBase }
    #expect(harness.lineCounts(of: tab) == sinceBase)
  }
}
