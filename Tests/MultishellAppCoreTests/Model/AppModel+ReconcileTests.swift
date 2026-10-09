import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelReconcileTests {
  /// The model has one alert slot, so what happens when several things fail at
  /// once has to be decided rather than left to whichever wrote last.
  @Test func onlyTheFirstFailedSessionTakesTheAlertAndTheRestAreLogged() {
    let harness = Harness()
    harness.model.select(harness.main)
    for _ in 0..<3 { harness.model.newTab() }
    #expect(harness.model.liveTerminalCount == 4)
    harness.engine.refusesToOpen = true
    for id in harness.engine.liveSessionIDs { harness.engine.close(id) }
    harness.model.presentedError = nil
    harness.platform.logged.removeAll()

    harness.model.reconcileSessions(takingFocus: false)

    #expect(harness.model.presentedError != nil, "the user is told once")
    #expect(
      harness.platform.logged.count == 3,
      "and the rest are in the log: \(harness.platform.logged)",
    )
  }

  @Test func focusingTheActivePaneHandsTheKeyboardToTheActiveTabsFocusedSession() throws {
    let harness = Harness()
    harness.model.select(harness.main)
    let tab = try #require(harness.model.workspace.activeTab(in: harness.main.id))
    harness.engine.focused.removeAll()

    harness.model.focusActivePane()

    #expect(harness.engine.focused == [tab.focusedSessionID])
  }

  @Test func focusingTheActivePaneDoesNothingWhileTheBoardCoversThePanes() {
    let harness = Harness()
    harness.model.select(harness.main)
    harness.model.showAgentBoard()
    harness.engine.focused.removeAll()

    harness.model.focusActivePane()

    #expect(harness.engine.focused.isEmpty)
  }
}
