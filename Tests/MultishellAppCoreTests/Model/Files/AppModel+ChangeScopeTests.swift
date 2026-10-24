import Foundation
import MultishellCore
import TestScratch
import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellGitKit

@Suite(.serialized) @MainActor
struct AppModelChangeScopeTests {
  @Test func switchingScopeReadsAgainOnlyTheTabsWhoseProjectHasABase() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    let other = try await harness.addSecondProject()
    let otherMain = try #require(harness.model.workspace.worktrees(of: other.id).first)
    let baseless = try #require(harness.model.openFileTab("README.md", in: otherMain))
    _ = try await harness.rowsArrive(in: baseless.id)
    harness.model.defaultBranchScans[other.id] = .absent
    let based = try #require(harness.model.openFileTab("README.md", in: feature))
    _ = try await harness.rowsArrive(in: based.id)

    harness.model.setChangeScope(.branch)

    #expect(harness.model.pendingFileTabReads[based.id] != nil)
    #expect(harness.model.pendingFileTabReads[baseless.id] == nil)
    #expect(!harness.model.fileTabReadLog.owed.contains(baseless.id))
  }

  @Test func aFileTabUnderBranchShowsWhatTheBranchCommittedAndOffersTheSwitch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    try await TestRepository.commit(
      "work",
      files: ["README.md": "hello\ncommitted\n"],
      in: feature.path,
      using: harness.git,
    )
    let tab = try #require(harness.model.openFileTab("README.md", in: feature))
    let modifiedRows = try #require(try await harness.rowsArrive(in: tab.id))
    #expect(!modifiedRows.hasLineChanges, "committed, so nothing against HEAD")
    #expect(harness.model.offersChangeScopeSwitch(for: tab))

    harness.model.setChangeScope(.branch)

    let sinceBase = FileLineCounts(insertions: 1, deletions: 0)
    try await waitUntil { harness.lineCounts(of: tab) == sinceBase }
    #expect(harness.lineCounts(of: tab) == sinceBase)
  }

  @Test func aFileTabInAProjectWithNoBaseBranchOffersNoSwitch() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let (tab, _) = try harness.openFileTab()
    harness.model.defaultBranchScans[harness.project.id] = .absent

    #expect(!harness.model.offersChangeScopeSwitch(for: tab))
  }

  @Test func leavingBranchLetsGoOfItsReadSoComingBackDrawsNoneAsCurrent() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    harness.model.setChangeScope(.branch)
    try await waitUntil { harness.model.branchChanges[feature.id] != nil }

    harness.model.setChangeScope(.modified)

    #expect(harness.model.branchChanges[feature.id] == nil)
  }

  @Test func switchingScopeWakesATabReadWaitingOutItsOldPace() async throws {
    let harness = try await GitHarness()
    defer { harness.tearDown() }
    let feature = try await harness.featureInGitList()
    let tab = try #require(harness.model.openFileTab("README.md", in: feature))
    _ = try await harness.rowsArrive(in: tab.id)
    harness.model.fileTabReadLog.begin(tab.id)
    _ = harness.model.fileTabReadLog.finish(tab.id, cost: .seconds(60))
    harness.model.noteFileTabChanged(tab.id)
    let waiting = try #require(harness.model.pendingFileTabReads[tab.id])

    harness.model.setChangeScope(.branch)

    #expect(harness.model.pendingFileTabReads[tab.id] != waiting)
    #expect(harness.model.fileTabReadLog.nextDue(tab.id) == nil, "a read due at once")
  }
}
