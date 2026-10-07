import MultishellProcess
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelSeenTests {
  /// Seen is the pane with the keyboard, not every pane on screen: a split's
  /// other pane keeps its Done, and its banner is still not raised.
  @Test func aDoneInAnUnfocusedPaneOfASplitStaysUntilThatPaneIsFocused() {
    let harness = Harness()
    harness.model.setNotificationPreference(.everyState)
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    harness.stateSource.send(SessionStateReport(state: .done, sessionID: other))
    #expect(harness.model.state(ofPane: other) == .done, "on screen, but nobody is in it")
    #expect(harness.notifier.posted.isEmpty, "and on screen, so no banner")

    harness.stateSource.send(SessionStateReport(state: .done, sessionID: focused))
    #expect(harness.model.state(ofPane: focused) == nil, "the focused pane's Done is seen at once")

    harness.model.show(pane: other)
    #expect(harness.model.state(ofPane: other) == nil, "focusing it is seeing it")
  }

  /// A bell or a title is activity in a pane nobody is in, whether or not
  /// that pane is on screen: seen is the pane with the keyboard.
  @Test func activityInAnUnfocusedPaneOfASplitRaisesItsDot() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let focused = tab.focusedSessionID
    let other = tab.sessionIDs.first { $0 != focused }!

    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: other)
    #expect(harness.model.state(ofPane: other) == .done, "on screen, but nobody is in it")

    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: focused)
    #expect(harness.model.state(ofPane: focused) == nil, "the keyboard is in it")
  }

  /// A click into a pane reaches the model as the engine's focus report,
  /// not as a store call of its own, so that report has to mark it seen too.
  @Test func clickingIntoAPaneSeesItsDone() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.splitActivePane(.horizontal)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let other = tab.sessionIDs.first { $0 != tab.focusedSessionID }!
    harness.stateSource.send(SessionStateReport(state: .done, sessionID: other))
    #expect(harness.model.state(ofPane: other) == .done)

    harness.engine.delegate?.terminalHost(harness.engine, didFocus: other)

    #expect(harness.model.workspace.tab(tab.id)?.focusedSessionID == other)
    #expect(harness.model.state(ofPane: other) == nil, "the keyboard is in it now")
  }

  /// The dot means "something happened here since you looked", and the tab an
  /// exit reveals is being looked at, as if clicked.
  @Test func aTabRevealedByAnExitLosesItsDot() {
    let harness = Harness()
    let first = harness.openBackgroundTab()
    let second = harness.model.workspace.activeTab(in: harness.main.id)!
    harness.engine.delegate?.terminalHost(harness.engine, didSeeActivityIn: first.focusedSessionID)
    #expect(harness.model.state(of: first) == .done)

    harness.engine.delegate?.terminalHost(harness.engine, didExit: second.focusedSessionID)

    #expect(harness.model.workspace.activeTab(in: harness.main.id)?.id == first.id)
    #expect(harness.model.state(of: first) == nil)
    #expect(harness.model.state(ofWorktree: harness.main.id) == nil)
  }
}
