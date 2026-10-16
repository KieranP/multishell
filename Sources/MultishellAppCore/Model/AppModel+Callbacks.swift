import MultishellCore

extension AppModel {
  /// What the platform, the reconciler, the socket, the notifier and the
  /// watcher report back or ask, each routed to the model.
  func wireCallbacks() {
    // Badges are read only while frontmost, so a return would show them as
    // stale as the last change. The permission is read back for the same reason.
    platform.onDidBecomeActive = { [weak self] in
      Task { await self?.refreshAll() }
      self?.refreshNotificationAuthorization()
      // Coming back is seeing the focused pane: a Done raised there while
      // the user was elsewhere clears now, and its banner goes with it.
      self?.markInViewSeen()
    }

    platform.onWorkspaceWindowDidBecomeVisible = { [weak self] in
      self?.readWhatTheWindowShowsOnceVisible()
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
    reconciler.onEditRequest = { [weak self] file, id in
      self?.openInEditor(file: file, clickedIn: id)
    }
    reconciler.onSearchCount = { [weak self] id, count in self?.noteSearchCount(count, in: id) }
    messageSource.onReport = { [weak self] report in self?.receive(report) }
    messageSource.onRequest = { [weak self] request in await self?.answer(request) }
    notifier.onActivate = { [weak self] key in self?.revealNotificationSubject(key) }
    watcher.onChange = { [weak self] changed in
      Task { await self?.noteFileChanges(changed) }
    }
  }
}
