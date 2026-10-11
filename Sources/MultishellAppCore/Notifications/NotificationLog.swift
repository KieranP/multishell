import Foundation

/// The newest banners posted, for `multishell debug notifications`, which
/// cannot see the notification centre; no view reads it.
struct NotificationLog: Sendable, Equatable {
  struct Entry: Sendable, Equatable {
    let title: String
    let body: String
    let key: SessionStates.Key
    let postedAt: Date
  }

  private static let capacity = 50

  private(set) var entries: [Entry] = []

  mutating func append(_ entry: Entry) {
    entries.append(entry)
    entries.keepLast(Self.capacity)
  }
}
