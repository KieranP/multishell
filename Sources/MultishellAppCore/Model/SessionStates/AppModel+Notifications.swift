import MultishellCore

extension AppModel {
  /// `state` is what the report meant, not what it said: a Done held back for
  /// background workers raises no banner, and the one releasing it does.
  func notifyIfNeeded(
    _ report: SessionStateReport, as state: SessionState, key: SessionStates.Key,
    worktreeID: Worktree.ID, isOnScreen: Bool
  ) {
    guard
      NotificationPolicy.shouldNotify(
        state, preference: workspace.notificationPreference, isOnScreen: isOnScreen,
        duration: report.duration, isSilent: report.isSilent == true),
      let worktree = workspace.worktree(worktreeID)
    else { return }
    let project = workspace.project(worktree.projectID)?.name ?? ""
    // The name the user gave the worktree: a notification arrives with the
    // app off screen, and the sidebar they picture says that.
    let place = workspace.displayName(of: worktree)
    let subject: String
    if case .session(let id) = key, let tab = workspace.tab(owning: id) {
      subject = title(of: tab)
    } else {
      subject = place
    }
    notifier.notify(
      title: NotificationPolicy.title(subject: subject, project: project, worktree: place),
      body: NotificationPolicy.body(for: state, message: report.shownMessage),
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
  func revealNotificationSubject(_ key: SessionStates.Key) {
    switch key {
    case .session(let id):
      guard let tab = workspace.tab(owning: id), let worktree = workspace.worktree(tab.worktreeID)
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
