import Foundation
import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelTabsTests {

  @Test func theFocusRingShowsOnlyWithAnotherPaneOnScreen() throws {
    let harness = Harness()
    harness.model.select(harness.main, openingFirstTab: .never)
    harness.model.newTab()
    let lone = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(!harness.model.showsFocusRing(in: lone))

    harness.model.newTab()
    harness.model.moveActiveTabToNewGroup()
    let beside = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(harness.model.workspace.groups(in: harness.main.id).count == 2)
    #expect(harness.model.showsFocusRing(in: beside))
  }

  @Test func aSplitTabWearsTheRingOnItsOwn() throws {
    let harness = Harness()
    harness.model.select(harness.main, openingFirstTab: .never)
    harness.model.newTab()
    harness.model.splitActivePane(.horizontal)

    let split = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    #expect(split.isSplit)
    #expect(harness.model.showsFocusRing(in: split))
  }
}
