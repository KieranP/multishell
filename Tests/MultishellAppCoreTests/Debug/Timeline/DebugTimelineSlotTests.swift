import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

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
      .sample(sequence: 0, cliExecutionsStartedCount: 2, stateReportCount: 1),
      .sample(
        sequence: 1,
        cliExecutionsStartedCount: 10,
        stateReportCount: 5,
        elapsed: .seconds(4),
      ),
    ])
    #expect(slot.cliExecutionsStartedPerSecond == 12.0 / 5)
    #expect(slot.stateReportsPerSecond == 6.0 / 5)
  }

  @Test func theSlowestSecondsFrameRateStandsForTheSlotNotTheMean() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, framesPerSecond: 120), .sample(sequence: 1, framesPerSecond: 30),
      .sample(sequence: 2, framesPerSecond: nil),
    ])
    #expect(slot.framesPerSecond == 30)
  }

  @Test func theAppsOwnMemoryStopsAtZeroWhereItsTerminalsReadMoreThanItsFootprint() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, appMemory: 400, terminalMemory: 500)
    ])
    #expect(slot.appMemoryOutsideTerminals == 0)
  }

  @Test func diskWakeupsAndFileEventsAreRatesOverTheTimeCovered() {
    let counts = DebugActivityCounts(
      diskBytesRead: 1_000,
      diskBytesWritten: 4_000,
      interruptWakeups: 50,
      packageIdleWakeups: 10,
    )
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, activity: counts, fileEventCount: 2),
      .sample(sequence: 1, activity: counts, fileEventCount: 8, elapsed: .seconds(4)),
    ])
    #expect(slot.diskBytesReadPerSecond == 400)
    #expect(slot.diskBytesWrittenPerSecond == 1_600)
    #expect(slot.interruptWakeupsPerSecond == 20)
    #expect(slot.packageIdleWakeupsPerSecond == 4)
    #expect(slot.fileEventsPerSecond == 2)
  }

  @Test func theWorstPressureStandsForTheSlotAndCountsAreTheLatest() {
    let slot = DebugTimelineSlot(samples: [
      .sample(sequence: 0, memoryPressure: .warning, peakMemory: 10, threadCount: 40),
      .sample(sequence: 1, memoryPressure: .normal, peakMemory: 20, threadCount: 41),
    ])
    #expect(slot.memoryPressure == .warning)
    #expect(slot.peakMemory == 20)
    #expect(slot.threadCount == 41)
  }

  @Test func otherThreadsAreWhatTheMainThreadAndTerminalsLeaveOfTheAppsCPU() {
    let slot = DebugTimelineSlot(samples: [
      .sample(
        sequence: 0,
        appCPUPercent: 30,
        mainThreadCPUPercent: 20,
        terminalThreadsCPUPercent: 4,
      )
    ])
    #expect(slot.otherThreadsCPUPercent == 6)

    let overRead = DebugTimelineSlot(samples: [
      .sample(
        sequence: 0,
        appCPUPercent: 10,
        mainThreadCPUPercent: 12,
        terminalThreadsCPUPercent: 4,
      )
    ])
    #expect(overRead.otherThreadsCPUPercent == 0)
  }
}
