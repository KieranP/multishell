import MultishellCore

extension AppModel {
  /// What the platform, the reconciler, the socket, the notifier and the
  /// watcher report back, each routed to the model.
  func wireCallbacks() {
    // Statuses poll only while frontmost, so a return would show badges five
    // seconds stale. The permission is read back for the same reason.
    platform.onDidBecomeActive = { [weak self] in
      Task { await self?.refreshAll() }
      self?.refreshNotificationAuthorization()
      // Coming back is seeing the focused pane: a Done raised there while
      // the user was elsewhere clears now, and its banner goes with it.
      self?.markInViewSeen()
    }

    reconciler.onActivity = { [weak self] id in self?.noteActivity(in: id) }
    reconciler.onCommandFinished = { [weak self] id, code in
      self?.noteCommandFinished(in: id, exitCode: code)
    }
    reconciler.onRetitle = { [weak self] id, title in self?.noteTitle(title, of: id) }
    // A click into a pane is looking at it: seen is the pane with the
    // keyboard, and a click is how the keyboard moves without a reconcile.
    reconciler.onFocus = { [weak self] _ in self?.markInViewSeen() }
    reconciler.onLiveSessionsChanged = { [weak self] in self?.noteLiveSessionsChanged() }
    reconciler.onCloseRequest = { [weak self] id in self?.closePane(id) }
    stateSource.onReport = { [weak self] report in self?.receive(report) }
    notifier.onActivate = { [weak self] key in self?.revealNotificationSubject(key) }
    watcher.onChange = { [weak self] changed in
      Task { await self?.refreshWorktreesIfRecordsChanged(under: changed) }
    }
  }
}
