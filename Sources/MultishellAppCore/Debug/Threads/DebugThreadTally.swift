/// The CPU the threads under one key spent, and how many of them ran.
struct DebugThreadTally: Sendable, Equatable {
  private(set) var threadCount: Int
  private(set) var cpuTime: Duration

  /// Over a range: the time added, the most threads any one sample saw.
  mutating func merge(_ other: Self) {
    threadCount = max(threadCount, other.threadCount)
    cpuTime += other.cpuTime
  }
}
