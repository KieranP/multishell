import Foundation

extension SessionStates {
  /// Stamps each key whose state changed, once per mutation, and a worker's start and
  /// failure. A state put back keeps its own stamp; a key the mutation dropped stays out.
  mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Array(entries.keys)
    where entries[key]?.state != previous.entries[key]?.state
      && (entries[key]?.since == nil || entries[key]?.since == previous.entries[key]?.since)
    {
      update(key) { stored in
        stored.since = now
        if stored.state == nil { stored.note = nil }
      }
    }
    for (key, entry) in entries where entry.roster.hasUnstampedTimes {
      update(key) { $0.roster.stampTimes(at: now) }
    }
  }
}
