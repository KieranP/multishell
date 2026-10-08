import Foundation

extension AppModel {
  /// One task, set for the next failed worker due to go and moved when that
  /// changes; see Docs/design/agents.md.
  func scheduleFailedWorkerSweep() {
    let due = sessionStates.nextFailedWorkerSweep(lingering: failedWorkerLingering)
    guard due != failedWorkerSweepDue else { return }
    failedWorkerSweep?.cancel()
    failedWorkerSweepDue = due
    guard let due else {
      failedWorkerSweep = nil
      return
    }
    failedWorkerSweep = Task { @MainActor [weak self] in
      // Past the due time, so the row stamped then is strictly before the cutoff.
      try? await Task.sleep(for: .seconds(max(0, due.timeIntervalSinceNow) + 0.1))
      guard !Task.isCancelled, let self else { return }
      failedWorkerSweep = nil
      failedWorkerSweepDue = nil
      let cutoff = Date().addingTimeInterval(-failedWorkerLingering)
      mutateStates { $0.removeFailedWorkers(failedBefore: cutoff) }
      scheduleFailedWorkerSweep()
    }
  }
}
