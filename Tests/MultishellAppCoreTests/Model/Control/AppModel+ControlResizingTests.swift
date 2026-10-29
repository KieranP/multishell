import CoreGraphics
import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelControlResizingTests {
  @Test func aSplitTakesTheSharesGivenAndTheAnswerPrintsThem() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)

    let reply = try #require(
      await harness.messageSource.ask(.resizeSplit(tab: tab.id, path: [], shares: [1, 3]))
    )

    let layout = try #require(reply.outputFields["layout"] as? [String: Any])
    #expect(layout["shares"] as? [Double] == [0.25, 0.75])
  }

  @Test func aSplitRefusesTheWrongCountAndAPathToAPane() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)

    let three = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [], shares: [1, 1, 1])
    )
    let intoAPane = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [0], shares: [1, 1])
    )

    #expect(three == .refused(.wrongShareCount(expected: 2)))
    #expect(intoAPane == .refused(.noSplit(id: tab.id, path: [0])))
  }

  @Test func groupsTakeTheirSharesAndTheTabListPrintsThem() async throws {
    let harness = Harness()
    let file = harness.openFileTab()
    harness.model.moveTab(file.id, .after, toNewGroupOf: file.groupID)
    let id = ControlID.worktree(harness.main.id)

    let reply = await harness.messageSource.ask(.resizeGroups(worktree: id, shares: [3, 1]))
    let listing = try #require(await harness.messageSource.ask(.listTabs(worktree: id)))

    #expect(reply == .done)
    let worktrees = try #require(listing.outputFields["worktrees"] as? [[String: Any]])
    #expect(worktrees.first?["groupShares"] as? [Double] == [0.75, 0.25])
  }

  @Test func aPanelsWidthGoesToThePlatformWithinWhatADragCouldReach() async {
    let harness = Harness()

    let sidebar = await harness.messageSource.ask(.setPanelWidth(.sidebar, width: 320))
    let narrow = await harness.messageSource.ask(.setPanelWidth(.filesPanel, width: 50))

    #expect(sidebar == .done)
    #expect(harness.platform.panelWidths == [.sidebar: 320])
    #expect(narrow == .refused(.widthOutOfRange(minimum: 200, maximum: 560)))
  }

  @Test func aShareThatLeavesAPaneNarrowerThanADragWouldIsRefused() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)
    let panes = try #require(harness.model.workspace.tab(tab.id)?.sessionIDs)
    harness.engine.frames = [
      panes[0]: CGRect(x: 0, y: 0, width: 400, height: 300),
      panes[1]: CGRect(x: 400, y: 0, width: 400, height: 300),
    ]

    let reply = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [], shares: [1, 100])
    )

    #expect(reply == .refused(.shareBelowMinimum(points: SplitMath.minimumPaneLength)))
  }

  @Test func theDividerBetweenPanesIsNotCountedAsRoomForThem() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)
    let panes = try #require(harness.model.workspace.tab(tab.id)?.sessionIDs)
    harness.engine.frames = [
      panes[0]: CGRect(x: 0, y: 0, width: 400, height: 300),
      panes[1]: CGRect(x: 406, y: 0, width: 400, height: 300),
    ]

    let reply = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [], shares: [0.0995, 0.9005])
    )

    #expect(reply == .refused(.shareBelowMinimum(points: SplitMath.minimumPaneLength)))
  }

  @Test func aSplitTooNarrowForTwoLeastPanesTakesAnyShares() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)
    let panes = try #require(harness.model.workspace.tab(tab.id)?.sessionIDs)
    harness.engine.frames = [
      panes[0]: CGRect(x: 0, y: 0, width: 72, height: 300),
      panes[1]: CGRect(x: 78, y: 0, width: 72, height: 300),
    ]

    let reply = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [], shares: [1, 1])
    )

    #expect(reply?.refusal == nil)
  }

  @Test func sharesSummingPastWhatADoubleHoldsAreRefused() async throws {
    let (harness, session) = Harness.withOnePane()
    let tab = try #require(harness.model.workspace.tab(owning: session.id))
    harness.model.splitActivePane(.horizontal)

    let reply = await harness.messageSource.ask(
      .resizeSplit(tab: tab.id, path: [], shares: [1e308, 1e308])
    )

    let shown = try #require(await harness.messageSource.ask(.describeTab(id: tab.id)))

    #expect(reply?.refusal != nil)
    let layout = try #require(shown.outputFields["layout"] as? [String: Any])
    #expect(layout["shares"] as? [Double] == [0.5, 0.5])
  }

  @Test func aSidebarWiderThanTheWindowIsRefused() async {
    let harness = Harness()

    let reply = await harness.messageSource.ask(.setPanelWidth(.sidebar, width: 100_000))

    #expect(reply == .refused(.widthOutOfRange(minimum: 180, maximum: 1_150)))
  }

  @Test func aSidebarIsHeldToTheRoomAnOpenFilesPanelLeaves() async {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsFilesPanel(true)
    harness.platform.panelWidths[.filesPanel] = 300

    let reply = await harness.messageSource.ask(.setPanelWidth(.sidebar, width: 1_000))

    #expect(reply == .refused(.widthOutOfRange(minimum: 180, maximum: 850)))
  }

  @Test func aWorktreeWithNoTabsHasNoGroupsToSize() async {
    let harness = Harness()
    let id = ControlID.worktree(harness.feature.id)

    let reply = await harness.messageSource.ask(.resizeGroups(worktree: id, shares: [1]))

    #expect(reply == .refused(.noGroups(id: id)))
  }
}
