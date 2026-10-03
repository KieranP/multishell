extension AppModel {
  /// Live while the panel is paused: the sidebar is never held.
  public var debugQuickStats: DebugQuickStats { DebugQuickStats(history: debugHistory) }
}
