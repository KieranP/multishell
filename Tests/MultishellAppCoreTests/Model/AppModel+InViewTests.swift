import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelInViewTests {
  @Test func aWorktreeIsInViewWhileSelectedAndNotUnderTheBoard() {
    let h = Harness()
    h.model.select(h.main, openingFirstTab: .never)
    #expect(h.model.isInView(h.main))
    #expect(!h.model.isInView(h.feature))

    h.model.showAgentBoard()

    #expect(!h.model.isInView(h.main))
  }

  @Test func onlyTheWorktreeInViewListsItsPanesInTheSidebar() {
    let h = Harness()
    h.model.select(h.feature)
    #expect(h.model.workspace.tabs(in: h.feature.id).count == 1)
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    h.model.newTab()

    #expect(h.model.sidebarPanes(of: h.main).count == 3)
    #expect(h.model.sidebarPanes(of: h.feature).isEmpty, "its pane is not listed")

    h.model.showAgentBoard()

    #expect(h.model.sidebarPanes(of: h.main).isEmpty)
  }
}
