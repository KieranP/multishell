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

  /// `state` is what the report meant, not what it said: a Done held back for
  /// background workers raises no banner, and the one releasing it does.
  func notifyIfNeeded(
    _ report: SessionStateReport, as state: SessionState, key: SessionStates.Key,
    worktreeID: Worktree.ID, isOnScreen: Bool
  ) {
    guard
      NotificationPolicy.shouldNotify(
        state, preference: workspace.notifications, isOnScreen: isOnScreen,
        duration: report.duration, silent: report.silent == true),
      let worktree = workspace.worktree(worktreeID)
    else { return }
    let project = workspace.project(worktree.projectID)?.name ?? ""
    // The name the user gave the worktree: a notification arrives with the
    // app off screen, and the sidebar they picture says that.
    let place = workspace.displayName(of: worktree)
    let subject: String
    if case .session(let id) = key, let tab = workspace.tabOwning(id) {
      subject = title(of: tab)
    } else {
      subject = place
    }
    notifier.notify(
      title: NotificationPolicy.title(subject: subject, project: project, worktree: place),
      body: NotificationPolicy.body(for: state, message: report.message),
      about: key)
    notifiedKeys.insert(key)
  }

  /// Takes a banner back where what it said has stopped being true. The dot
  /// is not touched; what goes is the interruption.
  func withdrawNotification(about key: SessionStates.Key) {
    guard notifiedKeys.remove(key) != nil else { return }
    notifier.withdraw(about: key)
  }

  /// A click on the notification: bring the tab, or the worktree, on screen.
  func reveal(_ key: SessionStates.Key) {
    switch key {
    case .session(let id):
      guard let tab = workspace.tabOwning(id), let worktree = workspace.worktree(tab.worktreeID)
      else { return }
      // A worktree whose directory has gone is not selected, and activating
      // a tab in it would rewrite what the selected worktree shows.
      guard select(worktree) else { return }
      activate(tab)
    case .worktree(let id):
      if let worktree = workspace.worktree(id) { select(worktree) }
    }
  }
}
