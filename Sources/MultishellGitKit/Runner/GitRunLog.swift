import Synchronization

/// Every git run timed while debug tools are on, shared by the runners a
/// launch builds. Off, it keeps nothing, so nothing grows undrained.
public final class GitRunLog: Sendable {
  private struct State {
    var isRecording = false
    var startedCount = 0
    var runningCount = 0
    var finishedRuns: [GitRun] = []
  }

  private let state = Mutex(State())

  /// Turning it off drops what was kept. The running count stays, the runs
  /// already started still finishing into it.
  public func setRecording(_ isRecording: Bool) {
    state.withLock { state in
      state.isRecording = isRecording
      guard !isRecording else { return }
      state.startedCount = 0
      state.finishedRuns = []
    }
  }

  /// Whether this run is timed. A `true` is answered by `endRun`.
  func beginRunIfRecording() -> Bool {
    state.withLock { state in
      guard state.isRecording else { return false }
      state.startedCount += 1
      state.runningCount += 1
      return true
    }
  }

  func endRun(_ run: GitRun) {
    state.withLock { state in
      state.runningCount = max(0, state.runningCount - 1)
      if state.isRecording { state.finishedRuns.append(run) }
    }
  }

  /// What came since the last drain, which this one starts afresh.
  public func drain() -> GitRunActivity {
    state.withLock { state in
      let activity = GitRunActivity(
        startedCount: state.startedCount,
        runningCount: state.runningCount,
        finishedRuns: state.finishedRuns,
      )
      state.startedCount = 0
      state.finishedRuns = []
      return activity
    }
  }
}
