import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

extension AppModelStatusReadsTests {
  @Test func anEditThatLeavesTheStatusAsItWasStillMovesBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["README.md": "b\n"],
      in: feature.path,
      using: harness.git,
    )
    let readme = feature.path.appending(path: "README.md")
    try "c\n".write(to: readme, atomically: true, encoding: .utf8)
    let names = { harness.model.fileTreeRows(of: feature.id).map(\.name) }
    harness.model.setChangeScope(.branch)
    await harness.model.refreshStatuses()
    try await waitUntil { names() == ["README.md"] }
    try await harness.statusReadsSettle(feature)
    try "hello\n".write(to: readme, atomically: true, encoding: .utf8)

    await harness.model.refreshStatuses()

    try await waitUntil { names() == [] }
    #expect(names() == [], "back to the base's text, though still +1 -1 against HEAD")
  }

  @Test func underStagedOnlyAFurtherEditOnDiskStillMovesBranch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.setGitStatusIndicator(.stagedOnly)
    harness.model.setChangeScope(.branch)
    let readme = feature.path.appending(path: "README.md")
    let insertions = { harness.model.filesPanelSummary(of: feature.id).insertions }
    try "hello\none\n".write(to: readme, atomically: true, encoding: .utf8)
    await harness.model.refreshStatuses()
    try await waitUntil { insertions() == 1 }
    try #require(insertions() == 1)
    try "hello\none\ntwo\n".write(to: readme, atomically: true, encoding: .utf8)

    await harness.model.refreshStatuses()

    try await waitUntil { insertions() == 2 }
    #expect(insertions() == 2)
  }

  @Test func aNewDiffAlgorithmReadsBranchAgain() async throws {
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

    harness.model.setDiffAlgorithm(.myers)

    var mergeBases = 0
    try await waitUntil {
      mergeBases += git.runLog.drain().finishedRuns.count { $0.command.hasPrefix("merge-base") }
      return mergeBases > 0
    }
    #expect(mergeBases > 0)
  }
}
