import MultishellCore
import Testing

@testable import MultishellAppUI

/// The find bar's steps in Ghostty's keybind spelling, which is the only
/// form libghostty takes them in; a misspelling is a step that does nothing.
@Suite
struct FindBindingActionTests {
  /// A find is the needle alone: a step sent with it runs before the engine
  /// has matched anything. From no selection Ghostty's `next` is the newest match.
  @Test func aFindIsTheNeedleAloneAndNearestIsGhosttysNextFromNoSelection() {
    #expect(GhosttyTerminalHost.bindingActions(for: .find("make -j")) == ["search:make -j"])
    #expect(GhosttyTerminalHost.bindingActions(for: .find("")) == ["search:"])
    #expect(GhosttyTerminalHost.bindingActions(for: .nearest) == ["navigate_search:next"])
  }

  /// Ghostty's `next` walks newest to oldest, which is up the scrollback;
  /// the app's Next walks down, so the two are crossed here.
  @Test func nextWalksDownAndPreviousUpWhichIsGhosttysOtherWayRound() {
    #expect(GhosttyTerminalHost.bindingActions(for: .next) == ["navigate_search:previous"])
    #expect(GhosttyTerminalHost.bindingActions(for: .previous) == ["navigate_search:next"])
    #expect(GhosttyTerminalHost.bindingActions(for: .end) == ["end_search"])
  }
}
