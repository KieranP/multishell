import MultishellProcess

/// Each process's share of one core since the last reading, as Activity
/// Monitor's CPU column has it: four busy cores read 400.
struct CPUUsageMeter {
  private var lastCPUTimes: [Int32: Duration] = [:]
  private var lastReadingAt: ContinuousClock.Instant?

  /// Percent by pid, and what children that exited since spent. A process
  /// first seen reads 0, as does every one on the first reading.
  mutating func takeReading(
    of processes: [ProcessUsage], exited: [(pid: Int32, cpuTime: Duration)] = [],
    at instant: ContinuousClock.Instant
  ) -> (byPID: [Int32: Double], exitedPercent: Double) {
    let current = Dictionary(
      keepingFirst:
        processes.map { ($0.pid, $0.cpuTime) })
    defer {
      lastCPUTimes = current
      lastReadingAt = instant
    }
    let elapsed = lastReadingAt.map { $0.duration(to: instant).inSeconds } ?? 0
    guard elapsed > 0 else { return (current.mapValues { _ in 0 }, 0) }
    let share = { (spent: Duration) in max(spent.inSeconds, 0) / elapsed * 100 }

    var byPID: [Int32: Double] = [:]
    for (pid, cpuTime) in current {
      guard let before = lastCPUTimes[pid] else {
        byPID[pid] = 0
        continue
      }
      byPID[pid] = share(cpuTime - before)
    }
    // One that started and ended between readings spent all of its time in
    // this one; one either scan saw counts only the time after it.
    let exitedPercent = exited.reduce(0) { total, child in
      total + share(child.cpuTime - (current[child.pid] ?? lastCPUTimes[child.pid] ?? .zero))
    }
    return (byPID, exitedPercent)
  }
}
