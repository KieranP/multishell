import MultishellCore

/// Whether a report deserves a system notification. Only reports, never
/// engine activity: a bell in a background tab is a dot, not a banner.
public enum NotificationPolicy {
  /// A command shorter than this is not worth a banner: a shell hook reports
  /// `ls` and a build alike, and only the build should be heard from.
  public static let minimumNotifiedDuration: Double = 10

  /// A tab the user is looking at in a frontmost app needs no banner; the
  /// same tab with the app in the background does, since the user is
  /// elsewhere.
  public static func shouldNotify(
    _ state: SessionState, preference: NotificationPreference, isShown: Bool, appIsActive: Bool,
    duration: Double? = nil
  ) -> Bool {
    guard preference.notifies(state) else { return false }
    if state.isFinished, let duration, duration < minimumNotifiedDuration { return false }
    return !(isShown && appIsActive)
  }

  /// The tab's title, or the worktree's name for a worktree-level report,
  /// then where it is.
  public static func title(subject: String, project: String, worktree: String) -> String {
    "\(subject) · \(project) › \(worktree)"
  }

  public static func body(for state: SessionState, message: String?) -> String {
    if let message, !message.isEmpty { return message }
    switch state {
    case .attention: return "Waiting for your input."
    case .done: return "Finished."
    case .error: return "Finished with an error."
    case .running, .idle: return state.displayName
    }
  }
}
