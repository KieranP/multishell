import Foundation
import MultishellProcess

extension Helper {
  /// Looks until `look` finds something or `timeout` runs out. `look` is
  /// handed the time left, so a look waiting on an answer cannot outlast it.
  static func poll<Found>(
    every interval: Duration,
    for timeout: Duration,
    _ look: (Duration) throws -> Found?,
  ) rethrows -> Found? {
    let deadline = ContinuousClock.now + timeout
    while true {
      let remaining = ContinuousClock.now.duration(to: deadline)
      guard remaining > .zero else { return nil }
      if let found = try look(remaining) { return found }
      Thread.sleep(forTimeInterval: min(interval, remaining).inSeconds)
    }
  }

  /// A look the deadline cut off mid-answer found nothing yet, so a wait ends
  /// saying how long it waited, not that one look went unanswered.
  static func notYetWhereCutShort<Found>(_ look: () throws -> Found?) throws -> Found? {
    do {
      return try look()
    } catch is SocketNoAnswer {
      return nil
    }
  }
}
