import Foundation
import MultishellCore

/// Everything Settings > Notifications says: a row per state a notification
/// can be asked for, and the note under them.
///
/// One row per state, since the states are wanted separately: a build
/// finishing is worth hearing about to someone who never wants a word about
/// a question.
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

  /// The caption at the foot of the page. What holds whichever toggles are
  /// on is said once here rather than behind each row's (i); a refusal
  /// replaces it, since the toggles above do nothing until it is lifted.
  ///
  /// `settingsLocation` is the desktop's own name for where permission is
  /// granted, from `Platform`, and no desktop is named here: the permission
  /// is a Mac's to ask for and a Linux notification daemon may never ask at
  /// all, which is what `unavailable` and `notAsked` tell this apart by.
  public static func note(
    for authorization: NotificationAuthorization, settingsLocation: String?
  ) -> String {
    switch authorization {
    case .refused:
      if let settingsLocation {
        "Notifications from Multishell are turned off in \(settingsLocation). Turn them on there, or these do nothing."
      } else {
        "Notifications from Multishell are turned off, so these do nothing until they are allowed again."
      }
    case .notAsked:
      "\(shownTabNote) Permission is asked for the first time you turn one of these on."
    case .allowed, .unavailable:
      shownTabNote
    }
  }

  /// True however the permission went, and the only thing left to say once
  /// it has been settled. The tail is what "frontmost" means to the person
  /// reading it, and it is not droppable: that same tab does notify once
  /// the user is off in another app.
  private static let shownTabNote =
    "The active tab on screen does not send notifications while you are working in Multishell."

  private static func info(for state: SessionState) -> String {
    switch state {
    case .attention:
      "An agent stopped for a permission prompt or a question."
    case .error:
      "An agent's turn failed, or a shell command exited non-zero. A command that ran under \(Int(NotificationPolicy.minimumNotifiedDuration)) seconds is not reported."
    case .done:
      "An agent finished its turn, or a shell command exited cleanly. A command that ran under \(Int(NotificationPolicy.minimumNotifiedDuration)) seconds is not reported."
    case .running, .idle:
      "Work in progress is never notified; the tab's dot says it."
    }
  }
}
