import MultishellCore
import MultishellProcess

/// Each thread's CPU since the last reading, by its id. A thread first seen
/// after the first reading started since it, so all its time counts.
struct ThreadCPUMeter {
  private var lastCPUTimes: [UInt64: Duration] = [:]
  private var lastReadingAt: ContinuousClock.Instant?

  mutating func takeReading(
    of threads: [ThreadUsage],
    at instant: ContinuousClock.Instant,
  ) -> DebugThreadCPU {
    // No threads means the read failed, and the meter waits for the next.
    guard !threads.isEmpty else { return .unmeasured }
    let isFirstReading = lastReadingAt == nil
    let elapsed = lastReadingAt.map { $0.duration(to: instant).inSeconds } ?? 0
    defer {
      lastCPUTimes = Dictionary(keepingFirst: threads.map { ($0.id, $0.cpuTime) })
      lastReadingAt = instant
    }
    guard !isFirstReading, elapsed > 0 else { return .unmeasured }
    let grouped = Dictionary(grouping: threads) { thread in
      DebugThreadKey(
        group: .of(threadNamed: thread.name, isMain: thread.isMain),
        name: thread.name,
      )
    }
    let byThread = grouped.mapValues { sharingKey in
      DebugThreadTally(
        threadCount: sharingKey.count,
        cpuTime: sharingKey.reduce(.zero) { total, thread in
          total + max(thread.cpuTime - (lastCPUTimes[thread.id] ?? .zero), .zero)
        },
      )
    }
    let percent = { (group: DebugThreadGroup) in
      byThread.filter { $0.key.group == group }.values.reduce(0) { $0 + $1.cpuTime.inSeconds }
        / elapsed * 100
    }
    return DebugThreadCPU(
      mainPercent: percent(.main),
      terminalsPercent: percent(.terminals),
      byThread: byThread,
    )
  }
}
