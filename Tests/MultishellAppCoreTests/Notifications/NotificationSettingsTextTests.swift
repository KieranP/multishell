import MultishellCore
import Testing

@testable import MultishellAppCore

/// What Settings > Notifications draws its toggles and its note from. The
/// tab is a view and untested; everything it says is here.
@Suite
struct NotificationSettingsTextTests {
  @Test func thereIsARowPerStateANotificationCanBeAskedFor() {
    #expect(NotificationSettingsText.rows.map(\.state) == NotificationPreference.notifiableStates)
    #expect(NotificationSettingsText.rows.map(\.title) == ["Waiting for input", "Failed", "Done"])
  }

  /// Help sits behind each row's (i), and the ten-second floor is named
  /// where it applies: a finished command is held to it, a question is not.
  @Test func eachRowCarriesItsHelpAndNamesTheFloorWhereItApplies() {
    for row in NotificationSettingsText.rows {
      #expect(!row.info.isEmpty, "\(row.state)")
    }
    #expect(
      NotificationSettingsText.rows.allSatisfy {
        !$0.info.contains(NotificationSettingsText.note(for: .notAsked, settingsLocation: nil))
      },
      "what holds for every notification is said once at the foot of the page")
    let floor = Int(NotificationPolicy.minimumNotifiedDuration)
    #expect(
      NotificationSettingsText.rows.filter { $0.info.contains("\(floor) seconds") }.map(\.state)
        == [.failed, .done],
      "waiting is never short")
  }

  /// The three toggles do nothing until a refusal is lifted, so where to lift it
  /// is all the note says then.
  @Test func aRefusalReplacesTheNoteAndSaysWhereToLiftIt() {
    let place = "System Settings > Notifications"
    let refused = NotificationSettingsText.note(for: .refused, settingsLocation: place)
    #expect(refused.contains(place), "the desktop names the place, not this")
    for authorization in [NotificationAuthorization.notAsked, .allowed, .unavailable] {
      #expect(
        NotificationSettingsText.note(for: authorization, settingsLocation: place) != refused,
        "\(authorization)")
    }
    #expect(
      !NotificationSettingsText.note(for: .refused, settingsLocation: nil).contains("Settings"),
      "a desktop with no such place is not sent to one")
  }

  /// A notification daemon that posts without permission answers `unavailable`,
  /// and a page there would promise a dialog nobody will see.
  @Test func onlyAnUnansweredPermissionPromisesToAsk() {
    #expect(
      NotificationSettingsText.note(for: .notAsked, settingsLocation: nil).contains("Permission"))
    for settled in [NotificationAuthorization.allowed, .unavailable] {
      #expect(
        !NotificationSettingsText.note(for: settled, settingsLocation: nil).contains("Permission"),
        "\(settled)")
    }
  }
}
