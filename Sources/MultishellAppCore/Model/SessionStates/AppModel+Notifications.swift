import Foundation
import MultishellCore

extension AppModel {
  /// The note's state is what a report meant, not what it said: a Done held
  /// back for background workers raises no banner, and the one releasing it does.
  func notifyIfNeeded(
    _ note: SessionNote,
    isSilent: Bool,
    key: SessionStates.Key,
    worktreeID: Worktree.ID,
    isOnScreen: Bool,
  ) {
    guard
      NotificationPolicy.shouldNotify(
        note.state,
        preference: workspace.notificationPreference,
        isOnScreen: isOnScreen,
        duration: note.duration,
        isSilent: isSilent,
      ),
      let worktree = workspace.worktree(worktreeID)
    else { return }
    let projectName = workspace.project(worktree.projectID)?.name ?? ""
    // The name the user gave the worktree: a notification arrives with the
    // app off screen, and the sidebar they picture says that.
    let worktreeName = workspace.displayName(of: worktree)
    let subject: String
    if case .session(let id) = key,
      let tab = workspace.tab(owning: id),
      let session = workspace.session(id)
    {
      subject = shownTitle(ofPane: session, in: tab, of: worktree)
    } else {
      subject = worktreeName
    }
    let title = NotificationPolicy.title(
      subject: subject,
      project: projectName,
      worktree: worktreeName,
    )
    postNotification(
      title: title,
      body: NotificationPolicy.body(for: note.state, message: note.message),
      about: key,
    )
  }

  /// Posts a banner and keeps what takes it back and what Debug Info lists.
  func postNotification(title: String, body: String, about key: SessionStates.Key) {
    notifier.notify(title: title, body: body, about: key)
    notifiedKeys.insert(key)
    notificationLog.append(.init(title: title, body: body, key: key, postedAt: Date()))
  }

  /// Takes a banner back where what it said has stopped being true. The dot
  /// is not touched; what goes is the interruption.
  func withdrawNotification(about key: SessionStates.Key) {
    guard notifiedKeys.remove(key) != nil else { return }
    notifier.withdraw(about: key)
  }

  /// A click on the notification: its pane, with the keyboard, or its worktree.
  func revealNotificationSubject(_ key: SessionStates.Key) {
    switch key {
    case .session(let id):
      reveal(pane: id)

    case .worktree(let id):
      if let worktree = workspace.worktree(id) { select(worktree) }
    }
  }
}
