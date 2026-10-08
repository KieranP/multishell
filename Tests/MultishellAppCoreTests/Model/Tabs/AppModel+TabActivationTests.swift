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

  @Test func aPaneShownFromItsRowBecomesTheFocusedPaneOfTheTabInView() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let first = try #require(harness.model.tabInView)
    harness.model.newTab()

    harness.model.show(pane: first.focusedSessionID)

    #expect(harness.model.tabInView?.id == first.id)
    #expect(harness.engine.focused.last == first.focusedSessionID)
  }
}
