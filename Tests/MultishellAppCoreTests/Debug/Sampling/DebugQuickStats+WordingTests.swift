import Testing

@testable import MultishellAppCore

@Suite
struct DebugQuickStatsWordingTests {
  @Test func everyCellSaysNoValueBeforeTheFirstSample() {
    let stats = DebugQuickStats(history: DebugHistory())
    #expect(stats.framesPerSecondText == "–")
    #expect(stats.totalCPUText == "–")
    #expect(stats.totalMemoryText == "–")
  }

  @Test func theCellsReadTheLastSampleWithTheirUnits() {
    let stats = DebugQuickStats(
      history: .of([
        .sample(sequence: 0, framesPerSecond: 59.6, appCPUPercent: 30, childrenCPUPercent: 4)
      ]))
    #expect(stats.framesPerSecondText == "60")
    #expect(stats.totalCPUText == "34%")
    #expect(stats.totalMemoryText == DebugValueText.memory(1_400))
  }
}
