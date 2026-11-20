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
    let (harness, session) = Harness.withOnePane()
    harness.model.setShowsSidebarFilter(true)
    harness.model.sidebarFilterText = "side"
    harness.engine.focused.removeAll()

    harness.model.setShowsSidebarFilter(false)

    #expect(!harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterText.isEmpty)
    #expect(harness.engine.focused == [session.id])
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

  @Test func filteringProjectsOpensTheFieldAndAsksForTheKeyboardEachTime() {
    let harness = Harness()
    harness.model.select(harness.main)

    harness.model.filterProjects()
    #expect(harness.model.showsSidebarFilter)
    #expect(harness.model.sidebarFilterFocusRequests == 1)

    harness.model.sidebarFilterText = "side"
    harness.model.filterProjects()

    #expect(harness.model.showsSidebarFilter, "a field already up stays up")
    #expect(harness.model.sidebarFilterText == "side")
    #expect(harness.model.sidebarFilterFocusRequests == 2)
  }

  @Test func filteringProjectsClosesTheQuickSwitcher() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.toggleQuickSwitcher(.all)
    #expect(harness.model.quickSwitcher != nil)

    harness.model.filterProjects()

    #expect(harness.model.quickSwitcher == nil)
  }
}
