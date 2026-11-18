import Testing

@testable import MultishellAppCore

@Suite
struct DebugQuickStatsTests {
  private func disk(_ bytes: UInt64) -> DebugActivityCounts {
    DebugActivityCounts(
      diskBytesRead: bytes / 4,
      diskBytesWritten: bytes - bytes / 4,
      interruptWakeups: 0,
      packageIdleWakeups: 0,
    )
  }

  @Test func theCellsReadTheLastSecondAndTheLastMinute() {
    let samples = (0..<90).map { sequence in
      DebugSample.sample(
        sequence: sequence,
        appCPUPercent: 10,
        childrenCPUPercent: Double(sequence % 3),
        childrenMemory: UInt64(1_000 + sequence),
        activity: disk(sequence == 89 ? 128_000 : 0),
      )
    }
    let stats = DebugQuickStats(history: .of(samples))

    #expect(stats.totalCPUPercent == 12, "the app and its children together")
    #expect(stats.totalMemory == 400 + 1_089)
    #expect(stats.diskBytesPerSecond == 128_000, "read and written together")
    #expect(stats.cpuTrend.count == 60)
    #expect(stats.cpuTrend.last == 0.12)
    #expect(stats.memoryTrend.count == 60)
    #expect(stats.memoryTrend.first == 0)
    #expect(stats.memoryTrend.last == 1, "the minute's own lowest to highest")
    #expect(stats.diskTrend.count == 60)
    #expect(stats.diskTrend.last.map { abs($0 - 1 / 1.1) < 0.0001 } == true)
  }

  @Test func diskIsARateOverTheTimeTheSampleCovered() {
    let stats = DebugQuickStats(
      history: .of([.sample(sequence: 0, activity: disk(8_000), elapsed: .seconds(4))])
    )
    #expect(stats.diskBytesPerSecond == 2_000)
  }

  @Test func aMinuteOfFlatMemoryIsDrawnAcrossTheMiddleRatherThanAlongTheFloor() {
    let stats = DebugQuickStats(history: .of((0..<3).map { .sample(sequence: $0) }))
    #expect(stats.memoryTrend == [0.5, 0.5, 0.5])
  }

  @Test func nothingSampledReadsAsNoValue() {
    let stats = DebugQuickStats(history: DebugHistory())
    #expect(stats.totalMemory == nil)
    #expect(stats.totalCPUPercent == nil)
    #expect(stats.diskBytesPerSecond == nil)
    #expect(stats.memoryTrend.isEmpty)
  }
}
