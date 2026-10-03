import MultishellCore

extension AppModel {
  public var showsDebugInfo: Bool { detailCover == .debugInfo }

  public var isDebugPaused: Bool { pausedDebugSnapshot != nil }

  /// The paused snapshot while there is one, else the latest.
  var shownDebugSnapshot: DebugSnapshot { pausedDebugSnapshot ?? liveDebugSnapshot }

  var liveDebugSnapshot: DebugSnapshot {
    DebugSnapshot(history: debugHistory, attribution: debugProcessAttribution)
  }

  /// View > Enable Debug Tools. Off drops every sample, stops git being
  /// timed, and puts the panes back where the panel covered them.
  public func setDebugToolsEnabled(_ enabled: Bool) {
    guard enabled != debugToolsEnabled else { return }
    debugToolsEnabled = enabled
    coordinator?.git.runLog.setRecording(enabled)
    if enabled {
      startDebugSampling()
    } else {
      stopDebugSamplingAndClear()
      if showsDebugInfo { uncoverDetail() }
    }
  }

  /// The quick stats' click: the panel covers the panes as the board does,
  /// and the board's wider PID watch narrows again.
  public func showDebugInfo() {
    guard debugToolsEnabled else { return }
    detailCover = .debugInfo
    updatePIDWatch()
  }

  /// Holds the panel still for reading; the sidebar and the sampling go on.
  public func setDebugPaused(_ paused: Bool) {
    pausedDebugSnapshot = paused ? liveDebugSnapshot : nil
  }
}
