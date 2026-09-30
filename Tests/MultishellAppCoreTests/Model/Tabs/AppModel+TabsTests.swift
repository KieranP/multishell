import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabsTests {

  @Test func theFocusRingShowsOnlyWithAnotherPaneOnScreen() throws {
    let h = Harness()
    h.model.select(h.main, openingFirstTab: .never)
    h.model.newTab()
    let lone = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(!h.model.showsFocusRing(in: lone))

    h.model.newTab()
    h.model.moveActiveTabToNewGroup()
    let beside = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(h.model.workspace.groups(in: h.main.id).count == 2)
    #expect(h.model.showsFocusRing(in: beside))
  }

  @Test func aSplitTabWearsTheRingOnItsOwn() throws {
    let h = Harness()
    h.model.select(h.main, openingFirstTab: .never)
    h.model.newTab()
    h.model.splitActivePane(.horizontal)

    let split = try #require(h.model.workspace.activeTab(in: h.main.id))
    #expect(split.isSplit)
    #expect(h.model.showsFocusRing(in: split))
  }
}
