import MultishellCore
import Testing

@testable import MultishellAppCore

@Suite @MainActor
struct AppModelSeenTests {
  /// Seen is the pane with the keyboard, not every pane on screen: a split's
  /// other pane keeps its Done, and its banner is still not raised.
  @Test func aDoneInAnUnfocusedPaneOfASplitStaysUntilThatPaneIsFocused() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, error: true, done: true))
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    h.source.send(SessionStateReport(state: .done, sessionID: other))
    #expect(h.model.state(ofPane: other) == .done, "on screen, but nobody is in it")
    #expect(h.notifier.posted.isEmpty, "and on screen, so no banner")

    h.source.send(SessionStateReport(state: .done, sessionID: focused))
    #expect(h.model.state(ofPane: focused) == nil, "the focused pane's Done is seen at once")

    h.model.show(pane: other)
    #expect(h.model.state(ofPane: other) == nil, "focusing it is seeing it")
  }

  /// A bell or a title is activity in a pane nobody is in, whether or not
  /// that pane is on screen: seen is the pane with the keyboard.
  @Test func activityInAnUnfocusedPaneOfASplitRaisesItsDot() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: other)
    #expect(h.model.state(ofPane: other) == .done, "on screen, but nobody is in it")

    h.engine.delegate?.terminalHost(h.engine, didSeeActivityIn: focused)
    #expect(h.model.state(ofPane: focused) == nil, "the keyboard is in it")
  }

  /// A click into a pane reaches the model as the engine's focus report,
  /// not as a store call of its own, so that report has to mark it seen too.
  @Test func clickingIntoAPaneSeesItsDone() {
    let h = Harness()
    h.model.select(h.main)
    h.model.splitActivePane(.horizontal)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let other = tab.sessionIDs.first { $0 != tab.focusedSessionID }!
    h.source.send(SessionStateReport(state: .done, sessionID: other))
    #expect(h.model.state(ofPane: other) == .done)

    h.engine.delegate?.terminalHost(h.engine, didFocus: other)

    #expect(h.model.workspace.tab(tab.id)?.focusedSessionID == other)
    #expect(h.model.state(ofPane: other) == nil, "the keyboard is in it now")
  }
}
