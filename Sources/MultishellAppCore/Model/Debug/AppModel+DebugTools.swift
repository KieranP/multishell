import MultishellCore
import MultishellGitKit

extension AppModel {
  public var showsDebugInfo: Bool { detailCover == .debugInfo }

  public var isDebugPaused: Bool { pausedDebugSnapshot != nil }

  var shownDebugSnapshot: DebugSnapshot { pausedDebugSnapshot ?? liveDebugSnapshot }

  private var liveDebugSnapshot: DebugSnapshot {
    DebugSnapshot(
      history: debugHistory,
      attribution: debugProcessAttribution,
      terminalMemoryBySession: debugTerminalMemoryBySession,
    )
  }

  /// View > Enable Debug Tools. Off drops every sample, stops git being
  /// timed, and puts the panes back where the panel covered them.
  public func setDebugToolsEnabled(_ enabled: Bool) {
    guard enabled != areDebugToolsEnabled else { return }
    areDebugToolsEnabled = enabled
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
    guard areDebugToolsEnabled else { return }
    detailCover = .debugInfo
    updatePIDWatch()
  }

  /// Holds the panel still for reading; the sidebar and the sampling go on.
  public func setDebugPaused(_ paused: Bool) {
    pausedDebugSnapshot = paused ? liveDebugSnapshot : nil
  }
}
