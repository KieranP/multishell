import Foundation
import Testing

@testable import MultishellAppCore
@testable import MultishellCore

@Suite @MainActor
struct AppModelNotificationsTests {
  @Test func notificationsFollowThePreferenceAndTheShownTab() {
    let h = Harness()
    h.source.send(SessionStateReport(state: .attention, cwd: h.main.path.path))
    #expect(h.notifier.posted.isEmpty, "off until turned on")
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    h.model.newTab()

    h.source.send(SessionStateReport(state: .running, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.isEmpty, "working is never a banner")

    h.source.send(
      SessionStateReport(
        state: .attention, sessionID: first.focusedSessionID, message: "Needs Bash"))
    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.posted.first?.body == "Needs Bash")
    #expect(h.notifier.posted.first?.title.contains("main") == true)
    #expect(h.notifier.posted.first?.key == .session(first.focusedSessionID))

    h.model.setNotifications(NotificationPreference(attention: true))
    h.source.send(SessionStateReport(state: .done, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.count == 1)

    h.model.setNotifications(.off)
    h.source.send(SessionStateReport(state: .attention, sessionID: first.focusedSessionID))
    #expect(h.notifier.posted.count == 1)

    // A click on the banner brings the tab back.
    h.notifier.onActivate?(.session(first.focusedSessionID))
    #expect(h.model.workspace.activeTab(in: h.main.id)?.id == first.id)
  }

  /// Once the agent is back at work the banner names something no longer true,
  /// so it goes rather than sitting in Notification Centre until swiped.
  @Test func aBannerIsTakenBackWhenTheStateItNamedMovesOn() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(h.notifier.posted.count == 1)
    #expect(h.notifier.withdrawn.isEmpty, "nothing has changed yet")

    h.source.send(SessionStateReport(state: .running, sessionID: session))
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.notifier.posted.count == 1, "working raises none of its own")

    h.source.send(SessionStateReport(state: .running, sessionID: session))
    #expect(h.notifier.withdrawn.count == 1, "taken back once, not on every report after")
  }

  /// Waiting survives being seen and its dot stays blue, but the banner has done
  /// its job.
  @Test func lookingAtThePaneTakesItsBannerBackAndLeavesTheDot() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .attention, sessionID: session))
    #expect(h.notifier.posted.count == 1)

    h.model.activate(tab)
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.model.sessionStates[.session(session)] == .attention, "the question still stands")
  }

  /// The dot and the banner must agree an on-screen pane is unseen while the
  /// user is away, and a shell exiting anywhere runs the seen-it pass.
  @Test func nothingCountsAsSeenWhileTheUserIsInAnotherApp() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let tab = h.model.workspace.activeTab(in: h.main.id)!
    let session = tab.focusedSessionID

    h.platform.isActive = false
    h.source.send(SessionStateReport(state: .done, sessionID: session))
    #expect(h.notifier.posted.count == 1, "shown, but nobody is looking")
    #expect(h.model.sessionStates[.session(session)] == .done, "and the dot says so too")

    h.model.reconcileSessions(takingFocus: true)
    #expect(h.notifier.withdrawn.isEmpty, "still away")
    #expect(h.model.sessionStates[.session(session)] == .done, "a shell exiting is not a look")

    h.platform.isActive = true
    h.platform.onDidBecomeActive?()
    #expect(h.notifier.withdrawn == [.session(session)], "back, and the pane is on screen")
    #expect(h.model.sessionStates[.session(session)] == nil, "seen now, so the dot goes as well")
  }

  @Test func closingATabTakesItsBannerWithIt() {
    let h = Harness()
    h.model.setNotifications(NotificationPreference(attention: true, failed: true, done: true))
    h.model.select(h.main)
    let first = h.model.workspace.activeTab(in: h.main.id)!
    let session = first.focusedSessionID
    h.model.newTab()

    h.source.send(SessionStateReport(state: .done, sessionID: session))
    #expect(h.notifier.posted.count == 1)

    h.model.closeTab(first.id)
    #expect(h.notifier.withdrawn == [.session(session)])
    #expect(h.model.notifiedKeys.isEmpty, "and nothing is left tracking it")
  }
}
