/// One kind of the app's own work added up over a sample or a range: how
/// many times, how long in all, the slowest, and what it wrote.
struct DebugWorkTally: Sendable, Equatable {
  static let empty = Self()

  private(set) var count = 0
  private(set) var totalDuration = Duration.zero
  private(set) var slowestDuration = Duration.zero
  private(set) var bytesWritten: UInt64 = 0

  // The tally's own count, not a collection's, which the rule takes it for.
  // swiftlint:disable:next empty_count
  var isEmpty: Bool { count == 0 }

  var meanDuration: Duration { isEmpty ? .zero : totalDuration / count }

  mutating func add(_ duration: Duration, bytesWritten bytes: UInt64 = 0) {
    count += 1
    totalDuration += duration
    slowestDuration = max(slowestDuration, duration)
    bytesWritten += bytes
  }

  mutating func merge(_ other: Self) {
    count += other.count
    totalDuration += other.totalDuration
    slowestDuration = max(slowestDuration, other.slowestDuration)
    bytesWritten += other.bytesWritten
  }
}
