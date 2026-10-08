import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSidebarFilterTests {
  @Test func emptyingTheFilterTextKeepsTheFieldUpAndTheKeyboardInIt() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.sidebarFilterText = "side"
    #expect(harness.model.showsSidebarFilter)
    harness.engine.focused.removeAll()

    harness.model.sidebarFilterText = ""

    let shown = harness.model.showsSidebarFilter
    #expect(shown, "the field has the keyboard and would take it away")
    #expect(harness.engine.focused.isEmpty)
  }

  @Test func closingTheFieldClearsItsTextAndHandsTheKeyboardToTheActivePane() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.setShowsSidebarFilter(true)
    harness.model.sidebarFilterText = "side"
    harness.engine.focused.removeAll()

    harness.model.setShowsSidebarFilter(false)

    #expect(!harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(harness.engine.focused == [tab.focusedSessionID])
  }

  @Test func togglingTheFilterOpensTheFieldThenClosesAndClearsIt() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.toggleSidebarFilter()
    #expect(harness.model.showsSidebarFilter)
    harness.model.sidebarFilterText = "side"

    harness.model.toggleSidebarFilter()
    #expect(!harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterText.isEmpty)
  }

  @Test func emptyingTheTextOfAFieldOpenedByHandLeavesItUp() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.setShowsSidebarFilter(true)
    harness.model.sidebarFilterText = "side"
    harness.engine.focused.removeAll()

    harness.model.sidebarFilterText = ""

    #expect(harness.model.showsSidebarFilter)
    #expect(harness.engine.focused.isEmpty)
  }
}
