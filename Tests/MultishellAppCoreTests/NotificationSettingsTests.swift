import MultishellCore
import Testing

@testable import MultishellAppCore

/// What Settings > Notifications draws its toggles and its note from. The
/// tab is a view and untested; everything it says is here.
@Suite
struct NotificationSettingsTests {
  /// One toggle per state a notification can be asked for, and no row for a
  /// state that never raises one.
  @Test func thereIsARowPerStateANotificationCanBeAskedFor() {
    #expect(NotificationSettings.rows.map(\.state) == NotificationPreference.notifiableStates)
    #expect(NotificationSettings.rows.map(\.title) == ["Waiting for input", "Failed", "Done"])
  }

  /// Help sits behind each row's (i), and the ten-second floor is named
  /// where it applies: a finished command is held to it, a question is not.
  @Test func eachRowCarriesItsHelpAndNamesTheFloorWhereItApplies() {
    for row in NotificationSettings.rows {
      #expect(!row.info.isEmpty, "\(row.state)")
    }
    #expect(
      NotificationSettings.rows.allSatisfy {
        !$0.info.contains(NotificationSettings.note(for: .notAsked, settingsLocation: nil))
      },
      "what holds for every notification is said once at the foot of the page")
    let floor = Int(NotificationPolicy.minimumNotifiedDuration)
    #expect(
      NotificationSettings.rows.filter { $0.info.contains("\(floor) seconds") }.map(\.state)
        == [.error, .done],
      "waiting is never short")
  }

  /// A refusal replaces the note rather than sitting beside it: the three
  /// toggles above do nothing until it is lifted, and where to lift it is
  /// the only thing worth saying then.
  @Test func aRefusalReplacesTheNoteAndSaysWhereToLiftIt() {
    let place = "System Settings > Notifications"
    let refused = NotificationSettings.note(for: .refused, settingsLocation: place)
    #expect(refused.contains(place), "the desktop names the place, not this")
    for authorization in [NotificationAuthorization.notAsked, .allowed, .unavailable] {
      #expect(
        NotificationSettings.note(for: authorization, settingsLocation: place) != refused,
        "\(authorization)")
    }
    #expect(
      !NotificationSettings.note(for: .refused, settingsLocation: nil).contains("Settings"),
      "a desktop with no such place is not sent to one")
  }

  /// Only a desktop that asks says it will: a notification daemon that
  /// posts without permission answers `unavailable`, and a page there would
  /// promise a dialog nobody will see.
  @Test func onlyAnUnansweredPermissionPromisesToAsk() {
    #expect(NotificationSettings.note(for: .notAsked, settingsLocation: nil).contains("Permission"))
    for settled in [NotificationAuthorization.allowed, .unavailable] {
      #expect(
        !NotificationSettings.note(for: settled, settingsLocation: nil).contains("Permission"),
        "\(settled)")
    }
  }
}

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

  /// A refusal is asked again the next time a state goes on: macOS answers
  /// from what it settled without showing its dialog, and the page needs
  /// the answer to say so.
  @Test func aRefusalIsShownAndAskedAgainOnTheNextToggle() async {
    let h = Harness()
    h.notifier.answer = .refused

    h.model.setNotifications(NotificationPreference(done: true))
    await h.settled()
    #expect(h.model.notificationAuthorization == .refused)
    #expect(
      NotificationSettings.note(
        for: h.model.notificationAuthorization,
        settingsLocation: h.platform.notificationSettingsLocation
      ).contains("System Settings"))

    h.model.setNotifications(NotificationPreference(attention: true, done: true))
    await h.settled()
    #expect(h.notifier.authorizationRequests == 2)
  }

  /// Coming back to the app is the return from the system settings a
  /// refusal points at, so the answer is read again there and the page does
  /// not sit on a refusal that has just been lifted.
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

  /// What the system settings say now, without asking for anything: the
  /// page reads it as it opens.
  @Test func thePageReadsTheStandingAnswerWithoutAsking() async {
    let h = Harness()
    h.notifier.answer = .refused

    h.model.refreshNotificationAuthorization()
    await h.settled()
    #expect(h.model.notificationAuthorization == .refused)
    #expect(h.notifier.authorizationRequests == 0, "reading is not asking")
  }
}
