import MultishellCore

/// Whether a report deserves a system notification. Only reports, never
/// engine activity: a bell in a background tab is a dot, not a banner.
public enum NotificationPolicy {
  /// A command shorter than this is not worth a banner: a shell hook reports
  /// `ls` and a build alike, and only the build should be heard from.
  public static let minimumNotifiedDuration: Double = 10

  /// A tab the user has seen needs no banner. Seen is the pane on screen and
  /// the app frontmost, the same notion `SessionStates` clears a Done against.
  public static func shouldNotify(
    _ state: SessionState, preference: NotificationPreference, isSeen: Bool,
    duration: Double? = nil, silent: Bool = false
  ) -> Bool {
    // Two reports stand for one permission prompt: the dot moves on the
    // first, the banner comes with the second.
    guard !silent, preference[state] else { return false }
    if state.isFinished, let duration, duration < minimumNotifiedDuration { return false }
    return !isSeen
  }

  /// The tab's title, or the worktree's name for a worktree-level report,
  /// then where it is.
  public static func title(subject: String, project: String, worktree: String) -> String {
    t("notification.title", subject, project, worktree)
  }

  public static func body(for state: SessionState, message: String?) -> String {
    if let message, !message.isEmpty { return message }
    switch state {
    case .attention: return t("notification.attention")
    case .done: return t("notification.done")
    case .error: return t("notification.error")
    case .running, .idle: return state.displayName
    }
  }
}
