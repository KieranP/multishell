import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelInViewTests {
  @Test func aWorktreeIsInViewWhileSelectedAndNotUnderTheBoard() {
    let harness = Harness()
    harness.model.select(harness.main, openingFirstTab: .never)
    #expect(harness.model.isInView(harness.main))
    #expect(!harness.model.isInView(harness.feature))

    harness.model.showAgentBoard()

    #expect(!harness.model.isInView(harness.main))
  }

  @Test func onlyTheFocusedGroupsFocusedPaneIsTheFocusedPaneAndNotUnderTheBoard() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.moveActiveTabToNewGroup()
    let groups = harness.model.workspace.groups(in: harness.main.id)
    try #require(groups.count == 2)
    let focused = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    let other = try #require(
      groups.compactMap { harness.model.workspace.shownTab(ofGroup: $0) }.first {
        $0.id != focused.id
      })

    #expect(harness.model.isFocusedPane(focused.focusedSessionID))
    #expect(!harness.model.isFocusedPane(other.focusedSessionID))

    harness.model.showAgentBoard()

    #expect(!harness.model.isFocusedPane(focused.focusedSessionID))
  }
}
