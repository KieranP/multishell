import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelNotificationsTests {
  @Test func aBackgroundPanesBannersFollowThePreference() {
    let harness = Harness()
    harness.stateSource.send(
      SessionStateReport(state: .attention, workingDirectory: harness.main.path.path))
    #expect(harness.notifier.posted.isEmpty, "off until turned on")
    harness.model.setNotifications(.everyState)
    let first = harness.openBackgroundTab()

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID))
    #expect(harness.notifier.posted.isEmpty, "working is never a banner")

    harness.stateSource.send(
      SessionStateReport(
        state: .attention, sessionID: first.focusedSessionID, message: "Needs Bash"))
    #expect(harness.notifier.posted.count == 1)
    #expect(harness.notifier.posted.first?.body == "Needs Bash")
    #expect(harness.notifier.posted.first?.title.contains("main") == true)
    #expect(harness.notifier.posted.first?.key == .session(first.focusedSessionID))

    harness.model.setNotifications(NotificationPreference(attention: true))
    harness.stateSource.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(harness.notifier.posted.count == 1)

    harness.model.setNotifications(.off)
    harness.stateSource.send(
      SessionStateReport(state: .attention, sessionID: first.focusedSessionID))
    #expect(harness.notifier.posted.count == 1)
  }

  @Test func aQuestionIsWordedAsOneOnTheBannerAndTheCardWhateverTheAgentSaid() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    let tab = harness.openBackgroundTab()
    harness.stateSource.send(
      SessionStateReport(
        state: .attention, sessionID: tab.focusedSessionID,
        message: "Claude needs your permission", asksQuestion: true))
    #expect(harness.notifier.posted.first?.body == "An agent needs your input")
    let card = harness.model.agentBoardCards.first { $0.id == tab.focusedSessionID }
    #expect(card?.message == "An agent needs your input")
  }

  /// Once the agent is back at work the banner names something no longer true,
  /// so it goes rather than sitting in Notification Centre until swiped.
  @Test func aBannerIsTakenBackWhenTheStateItNamedMovesOn() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let session = tab.focusedSessionID
    harness.model.newTab()

    harness.stateSource.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(harness.notifier.posted.count == 1)
    #expect(harness.notifier.withdrawn.isEmpty, "nothing has changed yet")

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: session))
    #expect(harness.notifier.withdrawn == [.session(session)])
    #expect(harness.notifier.posted.count == 1, "working raises none of its own")

    harness.stateSource.send(SessionStateReport(state: .running, sessionID: session))
    #expect(harness.notifier.withdrawn.count == 1, "taken back once, not on every report after")
  }

  /// Waiting survives being seen and its dot stays blue, but the banner has done
  /// its job.
  @Test func lookingAtThePaneTakesItsBannerBackAndLeavesTheDot() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let session = tab.focusedSessionID
    harness.model.newTab()

    harness.stateSource.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(harness.notifier.posted.count == 1)

    harness.model.activate(tab)
    #expect(harness.notifier.withdrawn == [.session(session)])
    #expect(
      harness.model.sessionStates[.session(session)] == .attention, "the question still stands")
  }

  /// The dot and the banner must agree an on-screen pane is unseen while the
  /// user is away, and a shell exiting anywhere runs the seen-it pass.
  @Test func nothingCountsAsSeenWhileTheUserIsInAnotherApp() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    harness.model.select(harness.main)
    let tab = harness.model.workspace.activeTab(in: harness.main.id)!
    let session = tab.focusedSessionID

    harness.platform.isActive = false
    harness.stateSource.send(SessionStateReport(state: .done, sessionID: session))
    #expect(harness.notifier.posted.count == 1, "shown, but nobody is looking")
    #expect(harness.model.sessionStates[.session(session)] == .done, "and the dot says so too")

    harness.model.reconcileSessions(takingFocus: true)
    #expect(harness.notifier.withdrawn.isEmpty, "still away")
    #expect(
      harness.model.sessionStates[.session(session)] == .done, "a shell exiting is not a look")

    harness.platform.isActive = true
    harness.platform.onDidBecomeActive?()
    #expect(harness.notifier.withdrawn == [.session(session)], "back, and the pane is on screen")
    #expect(
      harness.model.sessionStates[.session(session)] == nil, "seen now, so the dot goes as well")
  }

  @Test func closingATabTakesItsBannerWithIt() {
    let harness = Harness()
    harness.model.setNotifications(.everyState)
    harness.model.select(harness.main)
    let first = harness.model.workspace.activeTab(in: harness.main.id)!
    let session = first.focusedSessionID
    harness.model.newTab()

    harness.stateSource.send(SessionStateReport(state: .done, sessionID: session))
    #expect(harness.notifier.posted.count == 1)

    harness.model.closeTab(first.id)
    #expect(harness.notifier.withdrawn == [.session(session)])
    #expect(harness.model.notifiedKeys.isEmpty, "and nothing is left tracking it")
  }
}
