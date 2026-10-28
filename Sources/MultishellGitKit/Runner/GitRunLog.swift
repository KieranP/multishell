import Foundation
import MultishellProcess
import Synchronization

/// Every git run timed while debug tools are on, and `gh`'s and `circleci`'s
/// beside them; see services.md. Off, it keeps nothing, so nothing grows.
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

  /// `body`, `gh`'s and `circleci`'s too, timed as `command` while recording,
  /// handed a probe for the child's usage as it exits then and `nil` otherwise.
  public func timing<Result>(
    _ command: String,
    in directory: URL,
    _ body: (ExitUsageProbe?) async throws -> Result,
  ) async rethrows -> Result {
    guard beginRunIfRecording() else { return try await body(nil) }
    let started = ContinuousClock.now
    let exitUsageProbe = ExitUsageProbe()
    defer {
      endRun(
        GitRun(
          command: command,
          directory: directory,
          duration: started.duration(to: .now),
          exitUsage: exitUsageProbe.usage,
        )
      )
    }
    return try await body(exitUsageProbe)
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
