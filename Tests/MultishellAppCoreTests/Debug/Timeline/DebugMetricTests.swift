import Testing

@testable import MultishellAppCore

@Suite
struct DebugMetricTests {
  @Test func aFrameRateScalesToWholeSixtiesAndCPUToAtLeastOneCore() {
    #expect(DebugMetric.frameRate.scale(forPeak: 0) == 60)
    #expect(DebugMetric.frameRate.scale(forPeak: 61) == 120)
    #expect(DebugMetric.cpu.scale(forPeak: 40) == 100)
    #expect(DebugMetric.cpu.scale(forPeak: 250) == 250)
    #expect(DebugMetric.stateReports.scale(forPeak: 1) == 5)
  }
}
