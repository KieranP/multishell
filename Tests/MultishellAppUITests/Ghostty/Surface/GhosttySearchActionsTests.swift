import MultishellCore
import Testing

@testable import MultishellAppUI

@Suite
struct GhosttySearchActionsTests {
  @Test func aFindIsTheFindTextAloneAndNearestIsGhosttysNextFromNoSelection() {
    #expect(GhosttySearchActions.action(for: .find("make -j")) == "search:make -j")
    #expect(GhosttySearchActions.action(for: .find("")) == "search:")
    #expect(GhosttySearchActions.action(for: .nearest) == "navigate_search:next")
  }

  @Test func nextWalksDownAndPreviousUpWhichIsGhosttysOtherWayRound() {
    #expect(GhosttySearchActions.action(for: .next) == "navigate_search:previous")
    #expect(GhosttySearchActions.action(for: .previous) == "navigate_search:next")
    #expect(GhosttySearchActions.action(for: .end) == "end_search")
  }
}
