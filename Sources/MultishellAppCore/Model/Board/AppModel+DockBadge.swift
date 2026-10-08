extension AppModel {
  /// The count on the app's icon: what the Waiting column shows. Pushed, the
  /// port being a plain protocol with no way to watch a value.
  func updateDockBadge() {
    let waiting = boardLaneCounts[.waiting] ?? 0
    guard waiting != badgedWaitingCount else { return }
    badgedWaitingCount = waiting
    platform.setBadgeCount(waiting > 0 ? waiting : nil)
  }
}
