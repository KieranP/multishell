import MultishellCore

extension AppModel {
  /// Turning a state on asks the desktop for permission there and then,
  /// rather than at the first report hours later: the dialog belongs where
  /// the user asked for the thing it is about, and a refusal is worth
  /// learning while the page that says so is open.
  ///
  /// Only a state going on asks. Turning one off would otherwise ask on the
  /// way down, which is a question about something the user has just said
  /// they do not want. Asked again on each state that goes on while
  /// permission is not given, which costs nothing: a desktop that asks does
  /// so once and answers with the settled decision every time after.
  public func setNotifications(_ preference: NotificationPreference) {
    let turnedOnAState = NotificationPreference.notifiableStates.contains {
      preference[$0] && !workspace.notifications[$0]
    }
    store.setNotifications(preference)
    guard turnedOnAState, notificationAuthorization != .allowed else { return }
    Task { notificationAuthorization = await notifier.requestAuthorization() }
  }

  /// Reads what the desktop has been told without asking for anything, so
  /// the settings page shows a refusal made in another launch, or made in
  /// the system's own settings while the app was running. Run as the page
  /// opens and as the app comes back to the front, which is the return from
  /// the settings the refusal points at.
  public func refreshNotificationAuthorization() {
    Task { notificationAuthorization = await notifier.authorization() }
  }
}
