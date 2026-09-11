import Foundation
import MultishellCore

/// Everything Settings > Notifications says, a row per state: they are wanted
/// separately, a finished build by someone who wants no word of a question.
public enum NotificationSettings {
  /// One state's toggle, and what its (i) says about the reports behind it.
  public struct Row: Identifiable, Equatable, Sendable {
    public let state: SessionState
    public let title: String
    public let info: String

    public var id: SessionState { state }
  }

  public static let rows: [Row] =
    NotificationPreference.notifiableStates.map { state in
      Row(state: state, title: state.displayName, info: info(for: state))
    }

  /// The caption at the foot of the page, said once rather than behind each
  /// row's (i). A refusal replaces it; no desktop is named here.
  public static func note(
    for authorization: NotificationAuthorization, settingsLocation: String?
  ) -> String {
    switch authorization {
    case .refused:
      if let settingsLocation {
        t("notifications.refused-at", settingsLocation)
      } else {
        t("notifications.refused")
      }
    case .notAsked:
      t("notifications.not-asked", shownTabNote)
    case .allowed, .unavailable:
      shownTabNote
    }
  }

  /// True however the permission went. The tail is what "frontmost" means to
  /// the reader, and is not droppable.
  private static var shownTabNote: String { t("notifications.shown-tab") }

  private static func info(for state: SessionState) -> String {
    switch state {
    case .attention:
      t("notifications.attention-info")
    case .error:
      t("notifications.error-info", Int(NotificationPolicy.minimumNotifiedDuration))
    case .done:
      t("notifications.done-info", Int(NotificationPolicy.minimumNotifiedDuration))
    case .running, .idle:
      t("notifications.running-info")
    }
  }
}
