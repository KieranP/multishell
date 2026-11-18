import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMetricTests {
  @Test func aFrameRateScalesToWholeSixtiesAndCPUToAtLeastOneCore() {
    #expect(DebugMetric.frameRate.scale(forPeak: 0) == 60)
    #expect(DebugMetric.frameRate.scale(forPeak: 61) == 120)
    #expect(DebugMetric.cpu.scale(forPeak: 40) == 100)
    #expect(DebugMetric.cpu.scale(forPeak: 250) == 250)
    #expect(DebugMetric.stateReports.scale(forPeak: 1) == 5)
  }

  @Test func thePressureTileTopsOutAtCritical() {
    let slot = DebugTimelineSlot(samples: [.sample(sequence: 0, memoryPressure: .critical)])
    let value = DebugMetric.memoryPressure.values(of: slot)?.first ?? 0
    #expect(value == DebugMetric.memoryPressure.scale(forPeak: 0))
  }

  @Test func eachSplitTileGivesOneValuePerBandAndTheRestOne() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, memoryPressure: .normal, openDescriptorCount: 3)
    ])
    for metric in DebugMetric.allCases {
      let values = metric.values(of: slot)
      if metric == .frameRate { continue }
      #expect(values?.count == max(metric.series.count, 1), "\(metric)")
    }
  }

  @Test func aTileWithoutAReadingHasNoValue() {
    let slot = DebugTimelineSlot(samples: [.sample(sequence: 0, framesPerSecond: nil)])
    #expect(DebugMetric.frameRate.values(of: slot) == nil)
    #expect(DebugMetric.memoryPressure.values(of: slot) == nil)
    #expect(DebugMetric.openFiles.values(of: slot) == nil)
  }

  @Test func theTilesRunFromTheMostTellingOfASlowAppToTheLeast() {
    #expect(
      DebugMetric.allCases == [
        .frameRate, .cpu, .memory, .memoryPressure, .wakeups, .disk, .stateReports, .cliActivity,
        .fileEvents, .threads, .openFiles, .peakMemory,
      ]
    )
  }
}
