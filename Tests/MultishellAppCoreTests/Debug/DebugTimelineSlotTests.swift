import Testing

@testable import MultishellAppCore

@Suite
struct DebugTimelineSlotTests {
  @Test func cpuIsAveragedOverTheTimeEachSampleCoveredNotPerSample() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, appCPUPercent: 0, childrenCPUPercent: 0),
      .sample(sequence: 1, appCPUPercent: 100, childrenCPUPercent: 50, elapsed: .seconds(4)),
    ])
    #expect(slot.appCPUPercent == 80)
    #expect(slot.childrenCPUPercent == 40)
  }

  @Test func aRateIsCountedOverTheTimeTheSamplesCoveredNotOneSecondEach() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, gitRunsStartedCount: 2, stateReportCount: 1),
      .sample(sequence: 1, gitRunsStartedCount: 10, stateReportCount: 5, elapsed: .seconds(4)),
    ])
    #expect(slot.gitRunsStartedPerSecond == 12.0 / 5)
    #expect(slot.stateReportsPerSecond == 6.0 / 5)
  }

  @Test func theSlowestSecondsFrameRateStandsForTheSlotNotTheMean() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, framesPerSecond: 120), .sample(sequence: 1, framesPerSecond: 30),
      .sample(sequence: 2, framesPerSecond: nil),
    ])
    #expect(slot.framesPerSecond == 30)
  }
}
