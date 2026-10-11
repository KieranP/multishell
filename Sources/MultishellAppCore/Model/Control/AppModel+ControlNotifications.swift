import MultishellCore

extension AppModel {
  /// From the app's own log of what it posted: the centre itself says
  /// nothing of a banner once shown.
  func replyToDebugNotifications() -> ControlReply {
    // Only a key's newest banner can still be up; the centre replaced the rest.
    var newest: [SessionStates.Key: Int] = [:]
    for (index, entry) in notificationLog.entries.enumerated() { newest[entry.key] = index }
    let standing = Set(newest.filter { notifiedKeys.contains($0.key) }.values)
    return .json(
      DebugNotificationRecord(
        badge: badgedWaitingCount > 0 ? badgedWaitingCount : nil,
        banners: notificationLog.entries.enumerated().map { index, entry in
          var pane: TerminalSession.ID?
          var worktree: String?
          switch entry.key {
          case .session(let id): pane = id
          case .worktree(let id): worktree = ControlID.worktree(id)
          }
          return DebugNotificationRecord.Banner(
            title: entry.title,
            body: entry.body,
            pane: pane,
            worktree: worktree,
            postedAt: entry.postedAt,
            isStanding: standing.contains(index),
          )
        },
      )
    )
  }
}
