import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelPaneFocusTests {
  @Test func focusingTheNextPaneWalksTheTabInReadingOrderAndWraps() throws {
    let (harness, first) = Harness.withOnePane()
    harness.model.splitActivePane(.horizontal)
    harness.model.splitActivePane(.vertical)
    let tab = try #require(harness.model.tabInView)
    let panes = tab.root.sessionIDs
    #expect(panes.count == 3)
    #expect(tab.focusedSessionID == panes[2])

    harness.model.focusNextPane()

    #expect(harness.model.tabInView?.focusedSessionID == first.id)
    #expect(harness.engine.focused.last == first.id)

    harness.model.focusNextPane()
    #expect(harness.model.tabInView?.focusedSessionID == panes[1])
  }

  @Test func focusingThePreviousPaneWrapsFromTheFirstToTheLast() throws {
    let (harness, first) = Harness.withOnePane()
    harness.model.splitActivePane(.horizontal)
    harness.model.show(pane: first.id)
    let last = try #require(harness.model.tabInView?.root.sessionIDs.last)

    harness.model.focusPreviousPane()

    #expect(harness.model.tabInView?.focusedSessionID == last)
    #expect(harness.engine.focused.last == last)
  }

  @Test func aTabOfOnePaneOffersNoOtherPaneAndFocusGoesNowhere() {
    let (harness, _) = Harness.withOnePane()
    let before = harness.model.workspace

    harness.model.focusNextPane()
    harness.model.focusPreviousPane()

    #expect(!harness.model.canFocusAnotherPane)
    #expect(harness.model.workspace == before)
  }

  @Test func aSplitTabOffersAnotherPane() {
    let (harness, _) = Harness.withOnePane()
    harness.model.splitActivePane(.horizontal)

    #expect(harness.model.canFocusAnotherPane)
  }
}
