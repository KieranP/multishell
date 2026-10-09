import Foundation
import MultishellProcess

extension GitRunner {
  /// `body` timed into the run log while it records, handed a probe for
  /// git's usage as it exits then and `nil` otherwise.
  func logged<Result>(
    _ arguments: [String],
    in directory: URL,
    _ body: (ExitUsageProbe?) async throws -> Result,
  ) async rethrows -> Result {
    guard runLog.beginRunIfRecording() else { return try await body(nil) }
    let started = ContinuousClock.now
    let exitUsageProbe = ExitUsageProbe()
    defer {
      runLog.endRun(
        GitRun(
          command: GitCommandName.of(arguments),
          directory: directory,
          duration: started.duration(to: .now),
          exitUsage: exitUsageProbe.usage,
        )
      )
    }
    return try await body(exitUsageProbe)
  }
}
