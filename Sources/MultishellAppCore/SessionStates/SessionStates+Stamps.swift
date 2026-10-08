import Foundation

extension SessionStates {
  /// Records when each key's state changed, once per mutation, and stamps a
  /// worker's start and failure. A state put back with its own stamp keeps it.
  mutating func stampChanges(against previous: SessionStates, at now: Date) {
    for key in Set(entries.keys).union(previous.entries.keys)
    where entries[key]?.state != previous.entries[key]?.state
      && (entries[key]?.since == nil || entries[key]?.since == previous.entries[key]?.since)
    {
      update(key) {
        $0.since = now
        if $0.state == nil { $0.note = nil }
      }
    }
    for (key, entry) in entries where entry.roster.hasUnstampedTimes {
      update(key) { $0.roster.stampTimes(at: now) }
    }
  }
}
