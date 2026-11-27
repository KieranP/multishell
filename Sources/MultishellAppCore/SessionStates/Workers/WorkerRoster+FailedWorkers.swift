import Foundation

extension WorkerRoster {
  /// When the longest-failed row failed, `nil` with none stamped.
  var earliestFailure: Date? { workers.compactMap(\.failedAt).min() }

  /// Takes off the failed rows stamped before `cutoff`. Returns their ids.
  mutating func removeFailed(before cutoff: Date) -> [String] {
    let gone = workers.filter { $0.hasFailed && ($0.failedAt.map { $0 < cutoff } ?? false) }
      .map(\.id)
    retire(Set(gone))
    return gone
  }
}
