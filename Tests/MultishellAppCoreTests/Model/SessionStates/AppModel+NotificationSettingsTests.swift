import Testing

@testable import MultishellAppCore
@testable import MultishellCore

/// Permission is asked for where the user turns a notification on, not at
/// the first report hours later.
@Suite @MainActor
struct AppModelNotificationSettingsTests {
  @Test func turningAStateOnAsksAndKeepsTheAnswer() async {
    let harness = Harness()
    #expect(harness.model.notificationAuthorization == .notAsked)

    harness.model.setNotificationPreference(NotificationPreference(notifiesOnAttention: true))
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 1)
    #expect(harness.model.notificationAuthorization == .allowed)

    harness.model.setNotificationPreference(
      NotificationPreference(notifiesOnAttention: true, notifiesOnDone: true))
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 1)
  }

  /// A question about something the user has just said they do not want.
  @Test func turningAStateOffAsksNobody() async {
    let harness = Harness()
    harness.notifier.answer = .refused
    harness.model.setNotificationPreference(.off)
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 0)
    #expect(harness.model.notificationAuthorization == .notAsked, "nothing has been asked yet")

    harness.model.setNotificationPreference(
      NotificationPreference(notifiesOnAttention: true, notifiesOnDone: true))
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 1)

    harness.model.setNotificationPreference(NotificationPreference(notifiesOnAttention: true))
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 1, "one going off is not one going on")
  }

  /// macOS answers a repeat request from what it settled, without its dialog,
  /// and the page needs that answer to show the refusal.
  @Test func aRefusalIsShownAndAskedAgainOnTheNextToggle() async {
    let harness = Harness()
    harness.notifier.answer = .refused

    harness.model.setNotificationPreference(NotificationPreference(notifiesOnDone: true))
    await harness.settled()
    #expect(harness.model.notificationAuthorization == .refused)
    #expect(harness.model.notificationSettingsNote.contains("System Settings"))

    harness.model.setNotificationPreference(
      NotificationPreference(notifiesOnAttention: true, notifiesOnDone: true))
    await harness.settled()
    #expect(harness.notifier.authorizationRequests == 2)
  }

  /// Coming back to the app is the return from the system settings a refusal
  /// points at, so the page does not sit on a refusal just lifted.
  @Test func comingBackToTheFrontReadsTheAnswerAgain() async {
    let harness = Harness()
    harness.notifier.answer = .refused
    harness.platform.onDidBecomeActive?()
    await harness.settled()
    #expect(harness.model.notificationAuthorization == .refused)

    harness.notifier.answer = .allowed
    harness.platform.onDidBecomeActive?()
    await harness.settled()
    #expect(harness.model.notificationAuthorization == .allowed)
    #expect(harness.notifier.authorizationRequests == 0, "reading is not asking")
  }

  @Test func thePageReadsTheStandingAnswerWithoutAsking() async {
    let harness = Harness()
    harness.notifier.answer = .refused

    harness.model.refreshNotificationAuthorization()
    await harness.settled()
    #expect(harness.model.notificationAuthorization == .refused)
    #expect(harness.notifier.authorizationRequests == 0, "reading is not asking")
  }
}
