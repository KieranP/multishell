import MultishellCore
import Testing

@testable import MultishellAppCore

/// Permission is asked for where the user turns a notification on, not at
/// the first report hours later.
@Suite @MainActor
struct NotificationAuthorizationTests {
  @Test func turningAStateOnAsksAndKeepsTheAnswer() async {
    let h = Harness()
    #expect(h.model.notificationAuthorization == .notAsked)

    h.model.setNotifications(NotificationPreference(attention: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 1)
    #expect(h.model.notificationAuthorization == .allowed)

    // Already given, so a second toggle asks nobody.
    h.model.setNotifications(NotificationPreference(attention: true, done: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 1)
  }

  /// A question about something the user has just said they do not want.
  @Test func turningAStateOffAsksNobody() async {
    let h = Harness()
    h.notifier.answer = .refused
    h.model.setNotifications(.off)
    await h.settled()
    #expect(h.notifier.authorizationRequests == 0)
    #expect(h.model.notificationAuthorization == .notAsked, "nothing has been asked yet")

    h.model.setNotifications(NotificationPreference(attention: true, done: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 1)

    h.model.setNotifications(NotificationPreference(attention: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 1, "one going off is not one going on")
  }

  /// macOS answers a repeat request from what it settled, without its dialog,
  /// and the page needs that answer to show the refusal.
  @Test func aRefusalIsShownAndAskedAgainOnTheNextToggle() async {
    let h = Harness()
    h.notifier.answer = .refused

    h.model.setNotifications(NotificationPreference(done: true))
    await h.settled()
    #expect(h.model.notificationAuthorization == .refused)
    #expect(h.model.notificationSettingsNote.contains("System Settings"))

    h.model.setNotifications(NotificationPreference(attention: true, done: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 2)
  }

  /// Coming back to the app is the return from the system settings a refusal
  /// points at, so the page does not sit on a refusal just lifted.
  @Test func comingBackToTheFrontReadsTheAnswerAgain() async {
    let h = Harness()
    h.notifier.answer = .refused
    h.platform.onDidBecomeActive?()
    await h.settled()
    #expect(h.model.notificationAuthorization == .refused)

    h.notifier.answer = .allowed
    h.platform.onDidBecomeActive?()
    await h.settled()
    #expect(h.model.notificationAuthorization == .allowed)
    #expect(h.notifier.authorizationRequests == 0, "reading is not asking")
  }

  @Test func thePageReadsTheStandingAnswerWithoutAsking() async {
    let h = Harness()
    h.notifier.answer = .refused

    h.model.refreshNotificationAuthorization()
    await h.settled()
    #expect(h.model.notificationAuthorization == .refused)
    #expect(h.notifier.authorizationRequests == 0, "reading is not asking")
  }
}
