import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSidebarFilterTests {
  @Test func textLeftFromAnEarlierWindowKeepsTheFieldUpOnceItIsEmptied() {
    let h = Harness()
    h.model.select(h.main)
    h.model.sidebarFilterText = "side"
    #expect(h.model.showsSidebarFilter)
    h.engine.focused.removeAll()

    h.model.sidebarFilterText = ""

    let shown = h.model.showsSidebarFilter
    #expect(shown, "the field has the keyboard and would take it away")
    #expect(h.engine.focused.isEmpty)
  }

  @Test func closingTheFieldClearsItsTextAndHandsTheKeyboardToTheActivePane() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.model.setSidebarFilterOpen(true)
    h.model.sidebarFilterText = "side"
    h.engine.focused.removeAll()

    h.model.setSidebarFilterOpen(false)

    #expect(!h.model.showsSidebarFilter)
    #expect(h.model.sidebarFilterText.isEmpty)
    #expect(h.engine.focused == [tab.focusedSessionID])
  }

  @Test func emptyingTheTextOfAFieldOpenedByHandLeavesItUp() {
    let h = Harness()
    h.model.select(h.main)
    h.model.setSidebarFilterOpen(true)
    h.model.sidebarFilterText = "side"
    h.engine.focused.removeAll()

    h.model.sidebarFilterText = ""

    #expect(h.model.showsSidebarFilter)
    #expect(h.engine.focused.isEmpty)
  }
}
