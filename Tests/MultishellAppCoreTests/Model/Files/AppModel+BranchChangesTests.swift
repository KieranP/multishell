import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelBranchChangesTests {
  @Test func aCommitEmptiesModifiedWhileBranchStillListsTheWork() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "one\ntwo\n"],
      in: feature.path,
      using: harness.git,
    )
    let names = { harness.model.fileTreeRows(of: feature.id).map(\.name) }

    harness.model.setChangeScope(.branch)
    try await waitUntil { names() == ["work.txt"] }
    #expect(names() == ["work.txt"])
    #expect(harness.model.filesPanelSummary(of: feature.id).changedFiles == 1)
    #expect(harness.model.filesPanelSummary(of: feature.id).insertions == 2)

    harness.model.setChangeScope(.modified)
    await harness.model.refreshStatuses()
    #expect(names() == [])
  }

  @Test func branchListsAnUncommittedEditAsSoonAsItsStatusIsRead() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }
    try #require(harness.model.branchChanges[feature.id]?.changes == [])
    try "edited\n".write(
      to: feature.path.appending(path: "README.md"),
      atomically: true,
      encoding: .utf8,
    )

    await harness.model.refreshStatuses()

    let names = { harness.model.fileTreeRows(of: feature.id).map(\.name) }
    try await waitUntil { names() == ["README.md"] }
    #expect(names() == ["README.md"])
  }

  @Test func theFilesListCountsAgainstHeadWhateverTheScope() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    try await TestRepository.commit(
      "work",
      files: ["work.txt": "work\n"],
      in: feature.path,
      using: harness.git,
    )
    harness.model.setChangeScope(.branch)
    try await waitUntil { !harness.model.fileTreeRows(of: feature.id).isEmpty }

    harness.model.setFilesPanelMode(.files)
    harness.model.readFilesPanel(of: feature.id)
    await harness.model.refreshStatuses()

    let rows = { harness.model.fileTreeRows(of: feature.id) }
    try await waitUntil { rows().contains { $0.name == "work.txt" } }
    let row = try #require(rows().first { $0.name == "work.txt" })
    #expect(row.lineCounts == nil, "committed, so nothing against HEAD")
    #expect(harness.model.filesPanelSummary(of: feature.id).changedFiles == 0)
  }

  @Test func aProjectWithNoBaseBranchSaysSoUnderBranchAndListsNothing() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    try harness.dirty(feature)
    await harness.model.refreshStatuses()
    _ = try await harness.git.run(["branch", "-m", "main", "trunk"], in: harness.project.path)
    await harness.model.refreshBranchScan(of: harness.project)

    harness.model.setChangeScope(.branch)

    #expect(harness.model.fileTreeRows(of: feature.id).isEmpty)
    let summary = harness.model.filesPanelSummary(of: feature.id)
    #expect(FilesPanelFooterText.changes(summary) == t("files-panel.no-base"))
  }

  @Test func beforeItsProjectsFirstScanBranchClaimsNoMissingBase() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    harness.model.defaultBranchScans[harness.project.id] = nil

    harness.model.setChangeScope(.branch)

    let summary = harness.model.filesPanelSummary(of: feature.id)
    #expect(FilesPanelFooterText.changes(summary) == "")
  }

  @Test func branchWaitsForTheFirstStatusReadSoItsFirstListHasTheNewFiles() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    try harness.dirty(feature)
    try await harness.statusReadsSettle(feature)
    harness.clearStatuses()

    harness.model.setChangeScope(.branch)
    #expect(
      !harness.model.branchChangesReads.isRunning(feature.id),
      "no status to count new files",
    )
    await harness.model.refreshStatuses()

    let names = { harness.model.fileTreeRows(of: feature.id).map(\.name) }
    try await waitUntil { names() == ["dirty.txt"] }
    #expect(names() == ["dirty.txt"])
  }

  @Test func aBranchReadThatFailsSaysSoInTheFooter() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    await harness.model.refreshStatuses()
    harness.model.defaultBranchScans[harness.project.id] = .found(
      DefaultBranch(
        shortName: "gone",
        nameWithoutRemote: "gone",
        tip: "abc",
        fullName: "refs/heads/gone",
      )
    )

    harness.model.setChangeScope(.branch)
    let footer = { FilesPanelFooterText.changes(harness.model.filesPanelSummary(of: feature.id)) }
    try await waitUntil { !footer().isEmpty }

    #expect(footer() == t("files-panel.branch-unreadable", "gone"))
  }

  @Test func branchIsNotReadWhereItsProjectIsMissingAsStatusIsNot() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }
    try await waitUntil { !harness.model.branchChangesReads.isRunning(feature.id) }
    harness.model.missingProjects.insert(harness.project.id)

    harness.model.scheduleBranchChangesRead(of: feature.id)

    #expect(!harness.model.branchChangesReads.isRunning(feature.id))
  }

  @Test func aFailureAgainstTheOldBaseIsNotSaidOfTheNewOne() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInChangesList()
    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }
    harness.model.failedBranchReads[feature.id] = "old"
    harness.model.branchChanges[feature.id] = nil

    let footer = FilesPanelFooterText.changes(harness.model.filesPanelSummary(of: feature.id))

    #expect(footer == "", "nothing has tried this base yet")
  }
}
