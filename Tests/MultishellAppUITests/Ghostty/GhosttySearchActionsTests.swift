import MultishellCore
import Testing

@testable import MultishellAppUI

/// The find bar's steps in Ghostty's keybind spelling, which is the only
/// form libghostty takes them in; a misspelling is a step that does nothing.
@Suite
struct GhosttySearchActionsTests {
  /// A find is the find text alone: a step sent with it runs before the engine
  /// has matched anything. From no selection Ghostty's `next` is the newest match.
  @Test func aFindIsTheFindTextAloneAndNearestIsGhosttysNextFromNoSelection() {
    #expect(GhosttySearchActions.actions(for: .find("make -j")) == ["search:make -j"])
    #expect(GhosttySearchActions.actions(for: .find("")) == ["search:"])
    #expect(GhosttySearchActions.actions(for: .nearest) == ["navigate_search:next"])
  }

  /// Ghostty's `next` walks newest to oldest, which is up the scrollback;
  /// the app's Next walks down, so the two are crossed here.
  @Test func nextWalksDownAndPreviousUpWhichIsGhosttysOtherWayRound() {
    #expect(GhosttySearchActions.actions(for: .next) == ["navigate_search:previous"])
    #expect(GhosttySearchActions.actions(for: .previous) == ["navigate_search:next"])
    #expect(GhosttySearchActions.actions(for: .end) == ["end_search"])
  }
}
