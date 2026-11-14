import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

extension AppModelControlTabsTests {
  @Test func theListingAndTheDescriptionNameTheAllChangesTabsKindWithNoPathOrPanes() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    let listing = try #require(
      await harness.messageSource.ask(.listTabs(worktree: ControlID.worktree(harness.main.id)))
    )
    let description = try #require(await harness.messageSource.ask(.describeTab(id: tab.id)))

    let worktrees = try #require(listing.outputFields["worktrees"] as? [[String: Any]])
    let tabs = try #require(worktrees[0]["tabs"] as? [[String: Any]])
    #expect(tabs.compactMap { $0["kind"] as? String } == ["terminal", "all-changes"])
    #expect(tabs[1]["title"] as? String == "All changes")
    #expect(tabs[1]["path"] == nil && tabs[1]["panes"] == nil)
    #expect(description.outputFields["kind"] as? String == "all-changes")
  }

  @Test func theAllChangesTabRefusesARenameAndASplitAndClosesOnRequest() async throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.openAllChangesTab(in: harness.main.id))

    let rename = await harness.messageSource.ask(.renameTab(id: tab.id, title: "x"))
    let split = await harness.messageSource.ask(.splitPane(axis: .horizontal, tab: tab.id))
    let splitInView = await harness.messageSource.ask(.splitPane(axis: .horizontal, tab: nil))
    let close = await harness.messageSource.ask(.closeTab(id: tab.id, force: false))

    #expect(rename == .refused(.tabShowsAllChanges(id: tab.id)))
    #expect(split == .refused(.tabShowsAllChanges(id: tab.id)))
    #expect(splitInView == .refused(.tabShowsAllChanges(id: tab.id)))
    #expect(close == .done)
    #expect(harness.model.workspace.allChangesTabs.isEmpty)
  }

  @Test func openAllChangesOpensItOutOfViewWithoutSwitchingAndTurnsToItAfter() async throws {
    let harness = Harness()
    harness.model.select(harness.main)

    let first = await harness.messageSource.ask(
      .openAllChangesTab(worktree: ControlID.worktree(harness.feature.id))
    )
    let again = await harness.messageSource.ask(
      .openAllChangesTab(worktree: ControlID.worktree(harness.feature.id))
    )
    let gone = await harness.messageSource.ask(.openAllChangesTab(worktree: "w-00000000"))

    let tab = try #require(harness.model.workspace.allChangesTab(in: harness.feature.id))
    #expect(first?.outputFields["tab"] as? String == tab.id.uuidString)
    #expect(again?.outputFields["tab"] as? String == tab.id.uuidString)
    #expect(harness.model.workspace.selectedWorktreeID == harness.main.id)
    #expect(gone == .refused(.noWorktree(id: "w-00000000")))
  }
}
