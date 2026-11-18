import TestSupport
import Testing

@testable import MultishellAppCore
@testable import MultishellCore
@testable import MultishellGitKit

@MainActor
@Suite
struct AppModelAllChangesEmptyTextTests {
  @Test func nothingUncommittedNamesTheWorktreeAndOffersBranchWhereThereIsABase() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(.sample("main"))
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let name = harness.model.workspace.displayName(of: harness.main)

    let text = harness.model.allChangesEmptyText(of: tab)

    #expect(text.title == t("all-changes.no-uncommitted", name))
    #expect(text.detail == t("all-changes.branch-hint", "main"))
    #expect(harness.model.offersBranchScope(onEmpty: tab))
  }

  @Test func onlyASubmoduleChangedSaysSoRatherThanNothingChanged() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    let submodule = AllChangesFileChange(path: "sub", kind: .modified, lineCounts: nil)
    harness.model.allChangesReadings[tab.id] = AllChangesReading(listed: [submodule], files: [])

    let text = harness.model.allChangesEmptyText(of: tab)

    #expect(text.title == t("all-changes.only-nested-repositories"))
    #expect(text.detail == t("all-changes.only-nested-repositories-hint"))
  }

  @Test func onlyANestedRepositoryChangedSaysSo() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    var status = WorktreeStatus()
    status.setChanges([StatusChange(path: "vendor/x/", kind: .added, lines: .notCounted)])
    harness.model.statuses[harness.main.id] = status
    harness.model.allChangesReadings[tab.id] = AllChangesReading(listed: [], files: [])

    let text = harness.model.allChangesEmptyText(of: tab)

    #expect(text.title == t("all-changes.only-nested-repositories"))
  }

  @Test func nothingUncommittedWithNoBaseOffersNoBranch() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .absent
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    let text = harness.model.allChangesEmptyText(of: tab)

    #expect(text.detail == nil)
    #expect(!harness.model.offersBranchScope(onEmpty: tab))
  }

  @Test func nothingSinceTheBaseUnderBranchNamesTheBaseAndOffersNoSwitch() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(.sample("main"))
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.setChangeScope(.branch)

    let text = harness.model.allChangesEmptyText(of: tab)

    #expect(text.title == t("files-panel.no-branch-changes", "main"))
    #expect(text.detail == nil)
    #expect(!harness.model.offersBranchScope(onEmpty: tab))
  }

  @Test func aBranchReadThatFailedIsSaidInPlaceOfTheWait() throws {
    let harness = Harness()
    harness.model.defaultBranchScans[harness.project.id] = .found(.sample("main"))
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))
    harness.model.setChangeScope(.branch)
    #expect(harness.model.allChangesReadFailure(of: tab) == nil)

    harness.model.failedBranchReads[harness.main.id] = "main"

    #expect(
      harness.model.allChangesReadFailure(of: tab)?.title
        == t("files-panel.branch-unreadable", "main")
    )
  }
}
