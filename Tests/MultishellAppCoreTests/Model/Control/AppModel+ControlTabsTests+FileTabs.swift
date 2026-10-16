import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelControlTabsTests {
  @Test func theListingNamesAFileTabsKindAndPathAndNoPanes() async throws {
    let harness = Harness()
    let file = harness.openFileTab("Sources/App.swift")

    let reply = try #require(
      await harness.messageSource.ask(.listTabs(worktree: ControlID.worktree(harness.main.id)))
    )

    let worktrees = try #require(reply.outputFields["worktrees"] as? [[String: Any]])
    #expect(worktrees[0]["activeTab"] as? String == file.id.uuidString)
    let tabs = try #require(worktrees[0]["tabs"] as? [[String: Any]])
    #expect(tabs.compactMap { $0["kind"] as? String } == ["terminal", "file"])
    #expect(tabs[1]["path"] as? String == "Sources/App.swift")
    #expect(tabs[1]["title"] as? String == "App.swift")
    #expect(tabs[1]["panes"] == nil && tabs[1]["focusedPane"] == nil)
  }

  @Test func aDeletedFilesTabSaysSoInTheListingAndTheDescription() async throws {
    let harness = Harness()
    let file = harness.openFileTab()
    harness.model.fileTabReadings[file.id] = FileTabReading(content: .missing, isFileGone: true)

    let listing = try #require(
      await harness.messageSource.ask(.listTabs(worktree: ControlID.worktree(harness.main.id)))
    )
    let description = try #require(await harness.messageSource.ask(.describeTab(id: file.id)))

    let worktrees = try #require(listing.outputFields["worktrees"] as? [[String: Any]])
    let tabs = try #require(worktrees[0]["tabs"] as? [[String: Any]])
    #expect(tabs.map { $0["isDeleted"] as? Bool } == [nil, true])
    #expect(description.outputFields["isDeleted"] as? Bool == true)
  }

  @Test func aFileTabRefusesARenameAndASplitAndClosesOnRequest() async throws {
    let harness = Harness()
    let file = harness.openFileTab()

    let rename = await harness.messageSource.ask(.renameTab(id: file.id, title: "x"))
    let split = await harness.messageSource.ask(.splitPane(axis: .horizontal, tab: file.id))
    let close = await harness.messageSource.ask(.closeTab(id: file.id, force: false))

    #expect(rename == .refused(.tabShowsAFile(id: file.id)))
    #expect(split == .refused(.tabShowsAFile(id: file.id)))
    #expect(close == .done)
    #expect(harness.model.workspace.fileTabs.isEmpty)
  }

  @Test func aSplitAskedOfAFileTabElsewhereRefusesWithoutSwitchingToIt() async throws {
    let harness = Harness()
    let file = harness.openFileTab()
    harness.model.select(harness.feature)

    let split = await harness.messageSource.ask(.splitPane(axis: .horizontal, tab: file.id))

    #expect(split == .refused(.tabShowsAFile(id: file.id)))
    #expect(harness.model.worktreeInView?.id == harness.feature.id)
  }
}
