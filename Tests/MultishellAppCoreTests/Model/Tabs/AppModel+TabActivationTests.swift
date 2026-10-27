import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabActivationTests {
  @Test func nextAndPreviousTabWrapAtEitherEndOfTheStrip() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.newTab()
    harness.model.newTab()
    let tabs = harness.model.workspace.tabs(in: harness.main.id).map(\.id)
    try #require(tabs.count == 3)
    #expect(harness.model.tabInView?.id == tabs[2])

    harness.model.activateNextTab()
    #expect(harness.model.tabInView?.id == tabs[0])

    harness.model.activatePreviousTab()
    #expect(harness.model.tabInView?.id == tabs[2])

    harness.model.activatePreviousTab()
    #expect(harness.model.tabInView?.id == tabs[1])
  }

  @Test func showingAPaneOfAWorktreeNotSelectedLeavesItsStripAsItWas() throws {
    let harness = Harness()
    let background = harness.openBackgroundTab()
    let shown = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.model.select(harness.feature)

    harness.model.show(pane: background.focusedSessionID)

    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == shown.id)
  }

  @Test func showingAPaneUnderACoverLeavesTheKeyboardWhereItWas() throws {
    let harness = Harness()
    let background = harness.openBackgroundTab()
    harness.model.showAgentBoard()
    let focusesBefore = harness.engine.focused.count

    harness.model.show(pane: background.focusedSessionID)

    #expect(harness.engine.focused.count == focusesBefore)
  }

  @Test func aPaneShownFromItsRowBecomesTheFocusedPaneOfTheTabInView() {
    let harness = Harness()
    let first = harness.openBackgroundTab()

    harness.model.show(pane: first.focusedSessionID)

    #expect(harness.model.tabInView?.id == first.id)
    #expect(harness.engine.focused.last == first.focusedSessionID)
  }
}
