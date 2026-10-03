extension AppModel {
  public func debugTimeline(for range: DebugRange) -> DebugTimeline {
    DebugTimeline(history: shownDebugSnapshot.history, range: range)
  }
}
