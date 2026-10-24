import MultishellCore
import MultishellProcess

/// Runs an agent's CLI once for Auto Rename, and ends a run whose worktree
/// goes first. A test hands in `run`, a real one reading the developer's account.
@MainActor
final class OneShotRunner {
  var run: @Sendable (OneShotRequest) async throws -> ProcessOutput = { request in
    try await ProcessRunner().capture(
      request.executable,
      request.arguments,
      in: request.directory,
      environment: request.environment,
      timeout: request.timeout,
      stopper: request.stopper,
    )
  }
  private var stoppers: [Worktree.ID: ProcessStopper] = [:]

  /// The new run's stopper, held in place of any earlier run's for the worktree.
  func beginRun(for id: Worktree.ID) -> ProcessStopper {
    let stopper = ProcessStopper()
    stoppers[id] = stopper
    return stopper
  }

  /// Whether the run was still its worktree's, so its answer stands: a
  /// worktree made again at the path has a run of its own.
  func endRun(_ id: Worktree.ID, stopper: ProcessStopper) -> Bool {
    guard stoppers[id] === stopper else { return false }
    stoppers[id] = nil
    return true
  }

  func stop(_ ids: some Sequence<Worktree.ID>) {
    for id in ids { stoppers.removeValue(forKey: id)?.stop() }
  }

  func stopAll() {
    stop(Array(stoppers.keys))
  }
}
