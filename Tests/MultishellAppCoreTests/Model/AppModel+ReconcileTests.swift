import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelReconcileTests {
  /// The model has one alert slot, so what happens when several things fail at
  /// once has to be decided rather than left to whichever wrote last.
  @Test func onlyTheFirstFailedSessionTakesTheAlertAndTheRestAreLogged() {
    let h = Harness()
    h.model.select(h.main)
    for _ in 0..<3 { h.model.newTab() }
    #expect(h.model.liveTerminalCount == 4)
    h.engine.refusesToOpen = true
    for id in h.engine.openSessionIDs { h.engine.close(id) }
    h.model.presentedError = nil
    h.platform.logged.removeAll()

    h.model.reconcileSessions(takingFocus: false)

    #expect(h.model.presentedError != nil, "the user is told once")
    #expect(h.platform.logged.count == 3, "and the rest are in the log: \(h.platform.logged)")
  }

  @Test func focusingTheActivePaneHandsTheKeyboardToTheActiveTabsFocusedSession() throws {
    let h = Harness()
    h.model.select(h.main)
    let tab = try #require(h.model.workspace.activeTab(in: h.main.id))
    h.engine.focused.removeAll()

    h.model.focusActivePane()

    #expect(h.engine.focused == [tab.focusedSessionID])
  }

  @Test func focusingTheActivePaneDoesNothingWhileTheBoardCoversThePanes() {
    let h = Harness()
    h.model.select(h.main)
    h.model.showAgentBoard()
    h.engine.focused.removeAll()

    h.model.focusActivePane()

    #expect(h.engine.focused.isEmpty)
  }
}
