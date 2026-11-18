import Testing

@testable import MultishellAppCore

@Suite
struct DebugQuickStatsWordingTests {
  @Test func everyCellSaysNoValueBeforeTheFirstSample() {
    let stats = DebugQuickStats(history: DebugHistory())
    #expect(stats.totalCPUText == "–")
    #expect(stats.totalMemoryText == "–")
    #expect(stats.diskText == "–")
  }

  @Test func theCellsReadTheLastSampleWithTheirUnits() {
    let stats = DebugQuickStats(
      history: .of([
        .sample(
          sequence: 0,
          appCPUPercent: 30,
          childrenCPUPercent: 4,
          activity: DebugActivityCounts(
            diskBytesRead: 0,
            diskBytesWritten: 2_048,
            interruptWakeups: 0,
            packageIdleWakeups: 0,
          ),
        )
      ])
    )
    #expect(stats.totalCPUText == "34%")
    #expect(stats.totalMemoryText == DebugValueText.memory(1_400))
    #expect(stats.diskText == DebugValueText.memory(2_048), "the title carries the /s")
  }
}
