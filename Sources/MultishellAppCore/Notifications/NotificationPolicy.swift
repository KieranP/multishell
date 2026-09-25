import MultishellCore

/// Whether a report deserves a system notification. Only reports, never
/// engine activity: a bell in a background tab is a dot, not a banner.
enum NotificationPolicy {
  /// A command shorter than this is not worth a banner: a shell hook reports
  /// `ls` and a build alike, and only the build should be heard from.
  static let minimumNotifiedDuration: Double = 10

  /// A pane on screen needs no banner: in view and the app frontmost. Wider
  /// than what clears a Done, which is the focused pane alone.
  static func shouldNotify(
    _ state: SessionState, preference: NotificationPreference, isOnScreen: Bool,
    duration: Double? = nil, silent: Bool = false
  ) -> Bool {
    // Two reports stand for one permission prompt: the dot moves on the
    // first, the banner comes with the second.
    guard !silent, preference[state] else { return false }
    if state.isFinished, let duration, duration < minimumNotifiedDuration { return false }
    return !isOnScreen
  }

  /// The tab's title, or the worktree's name for a worktree-level report,
  /// then where it is.
  static func title(subject: String, project: String, worktree: String) -> String {
    t("notification.title", subject, project, worktree)
  }

  static func body(for state: SessionState, message: String?) -> String {
    if let message, !message.isEmpty { return message }
    switch state {
    case .attention: return t("notification.attention")
    case .done: return t("notification.done")
    case .failed: return t("notification.error")
    case .running, .idle: return state.displayName
    }
  }
}
