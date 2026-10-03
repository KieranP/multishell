import Testing

@testable import MultishellAppCore

@Suite
struct DebugQuickStatsTests {
  @Test func theCellsReadTheLastSecondAndTheLastMinute() {
    let samples = (0..<90).map {
      DebugSample.sample(
        sequence: $0, framesPerSecond: $0 == 89 ? 59.6 : 120, longestFrame: .milliseconds(60),
        appCPUPercent: 10, childrenCPUPercent: Double($0 % 3), childrenMemory: UInt64(1_000 + $0))
    }
    let stats = DebugQuickStats(history: .of(samples))

    #expect(stats.framesPerSecond == 60)
    #expect(stats.smoothness == .hitched)
    #expect(stats.totalCPUPercent == 12, "the app and its children together")
    #expect(stats.totalMemory == 400 + 1_089)
    #expect(stats.frameRateTrend.count == 60)
    #expect(stats.memoryTrend.first == 0)
    #expect(stats.memoryTrend.last == 1, "the minute's own lowest to highest")
  }

  @Test func aSecondWithNoFrameIsLeftOutOfTheFrameRateTrendRatherThanDrawnAsZero() {
    let samples = (0..<3).map {
      DebugSample.sample(sequence: $0, framesPerSecond: $0 == 1 ? nil : 120)
    }
    let stats = DebugQuickStats(history: .of(samples))
    #expect(stats.frameRateTrend.count == 2)
    #expect(!stats.frameRateTrend.contains(0))
  }

  @Test func aMinuteOfFlatMemoryIsDrawnAcrossTheMiddleRatherThanAlongTheFloor() {
    let stats = DebugQuickStats(history: .of((0..<3).map { .sample(sequence: $0) }))
    #expect(stats.memoryTrend == [0.5, 0.5, 0.5])
  }

  @Test func nothingSampledReadsAsNoValue() {
    let stats = DebugQuickStats(history: DebugHistory())
    #expect(stats.framesPerSecond == nil)
    #expect(stats.totalMemory == nil)
    #expect(stats.totalCPUPercent == nil)
    #expect(stats.memoryTrend.isEmpty)
  }
}
