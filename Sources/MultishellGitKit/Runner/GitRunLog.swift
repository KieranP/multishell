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

  init() {}

  /// Turning it off drops what was kept. The running count stays, the runs
  /// already started still finishing into it.
  public func setRecording(_ isRecording: Bool) {
    state.withLock {
      $0.isRecording = isRecording
      guard !isRecording else { return }
      $0.startedCount = 0
      $0.finishedRuns = []
    }
  }

  /// Whether this run is timed. A `true` is answered by `endRun`.
  func beginRunIfRecording() -> Bool {
    state.withLock {
      guard $0.isRecording else { return false }
      $0.startedCount += 1
      $0.runningCount += 1
      return true
    }
  }

  func endRun(_ run: GitRun) {
    state.withLock {
      $0.runningCount = max(0, $0.runningCount - 1)
      if $0.isRecording { $0.finishedRuns.append(run) }
    }
  }

  /// What came since the last drain, which this one starts afresh.
  public func drain() -> GitRunActivity {
    state.withLock {
      let activity = GitRunActivity(
        startedCount: $0.startedCount, runningCount: $0.runningCount,
        finishedRuns: $0.finishedRuns)
      $0.startedCount = 0
      $0.finishedRuns = []
      return activity
    }
  }
}
