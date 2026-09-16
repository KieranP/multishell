import MultishellCore

extension AppModel {
  /// Turning a state on asks for permission there and then, where the user
  /// asked for the thing it is about. Only on the way up.
  public func setNotifications(_ preference: NotificationPreference) {
    let turnedOnAState = NotificationPreference.notifiableStates.contains {
      preference[$0] && !workspace.notifications[$0]
    }
    store.setNotifications(preference)
    guard turnedOnAState, notificationAuthorization != .allowed else { return }
    Task { notificationAuthorization = await notifier.requestAuthorization() }
  }

  /// Reads what the desktop has been told without asking, so a refusal made
  /// elsewhere shows. Run as the page opens and on returning to the front.
  public func refreshNotificationAuthorization() {
    Task { notificationAuthorization = await notifier.authorization() }
  }

  /// The caption under the toggles. Here rather than in the view because it
  /// names where the desktop keeps its settings, which is the port's to say.
  public var notificationSettingsNote: String {
    NotificationSettings.note(
      for: notificationAuthorization, settingsLocation: platform.notificationSettingsLocation)
  }
}
