import Foundation

extension WorkerRoster {
  var hasUnstampedTimes: Bool {
    workers.contains { $0.startedAt == nil || ($0.hasFailed && $0.failedAt == nil) }
  }

  /// A start's time, and a failure's, which the sweep counts from.
  mutating func stampTimes(at now: Date) {
    for index in workers.indices {
      if workers[index].startedAt == nil { workers[index].startedAt = now }
      if workers[index].hasFailed, workers[index].failedAt == nil {
        workers[index].failedAt = now
      }
    }
  }
}
