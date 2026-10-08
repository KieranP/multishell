import Foundation

/// A killed or failed worker drawn as failed for a while, as Claude Code
/// draws it; see Docs/design/agents.md.
extension SessionStates {
  /// How long a failed worker stays listed: Claude Code 2.1.292's own `pP`.
  static let failedWorkerLingering: TimeInterval = 30

  /// When the next failed worker is due to go, `nil` with none.
  func nextFailedWorkerSweep(lingering: TimeInterval) -> Date? {
    entries.values.compactMap(\.roster.earliestFailure).min()
      .map { $0.addingTimeInterval(lingering) }
  }

  mutating func removeFailedWorkers(failedBefore cutoff: Date) {
    for (key, entry) in entries where entry.roster.earliestFailure.map({ $0 < cutoff }) == true {
      update(key) {
        let gone = $0.roster.removeFailed(before: cutoff)
        for id in gone { $0.promptRaisers.remove(.worker(id)) }
      }
    }
  }
}
