import Testing

@testable import MultishellAppCore
@testable import MultishellProcess

@Suite
struct DebugMetricWordingTests {
  private let slot = DebugTimelineSlot(samples: [
    DebugSample.sample(
      sequence: 0,
      framesPerSecond: nil,
      cliExecutionsStartedCount: 3,
      appCPUPercent: 10,
      childrenCPUPercent: 25,
      terminalMemory: 150,
      mainThreadCPUPercent: 6,
      terminalThreadsCPUPercent: 3,
      activity: DebugActivityCounts(
        diskBytesRead: 1_024,
        diskBytesWritten: 2_048,
        interruptWakeups: 30,
        packageIdleWakeups: 8,
      ),
      memoryPressure: .warning,
      threadCount: 41,
      openDescriptorCount: 63,
    )
  ])

  @Test func aSplitTileSaysEachBandsShareUnderItsTotal() {
    #expect(DebugMetric.cpu.valueText(of: slot) == "35%")
    #expect(
      DebugMetric.cpu.detailText(of: slot)
        == "Main 6% · Terminals 3% · Other 1% · Child processes 25%"
    )
    #expect(
      DebugMetric.memory.detailText(of: slot)
        == "App \(DebugValueText.memory(250)) · Terminals \(DebugValueText.memory(150)) · "
        + "Child processes \(DebugValueText.memory(1_000))"
    )
    #expect(DebugMetric.wakeups.valueText(of: slot) == "30/s", "package idle is part of interrupt")
    #expect(
      DebugMetric.wakeups.detailText(of: slot) == "Interrupt 30/s, of which package idle 8/s"
    )
    #expect(DebugMetric.disk.valueText(of: slot) == "\(DebugValueText.memory(3_072))/s")
  }

  @Test func countsReadAsPlainNumbersAndThePressureByItsLevel() {
    #expect(DebugMetric.threads.valueText(of: slot) == "41")
    #expect(DebugMetric.openFiles.valueText(of: slot) == "63")
    #expect(DebugMetric.memoryPressure.valueText(of: slot) == "Warning")
  }

  @Test func aTileWithNoReadingOrNothingRunningSaysSo() {
    #expect(DebugMetric.frameRate.valueText(of: slot) == "–")
    #expect(DebugMetric.cliActivity.valueText(of: slot) == "3/s")
    #expect(DebugMetric.cliActivity.detailText(of: slot) == nil, "no git still running")
    #expect(DebugMetric.stateReports.detailText(of: slot) == nil, "no report to time")
  }

  @Test func everyTileSaysNoValueBeforeItsFirstSample() {
    for metric in DebugMetric.allCases {
      #expect(metric.valueText(of: nil) == "–", "\(metric)")
    }
  }

  @Test func gitStillRunningAtTheSampleIsCountedUnderTheRate() {
    let running = DebugTimelineSlot(samples: [.sample(sequence: 0, cliExecutionsRunningCount: 2)])
    #expect(DebugMetric.cliActivity.detailText(of: running) == "2 running")
  }

  @Test func reportsHandledSayHowLongTheyTook() {
    var sample = DebugSample.sample(sequence: 0)
    var reports = DebugWorkTally.empty
    reports.add(.milliseconds(2))
    reports.add(.milliseconds(6))
    sample = DebugSample(
      sequence: sample.sequence,
      takenAt: sample.takenAt,
      elapsed: sample.elapsed,
      frameRate: sample.frameRate,
      cliExecutionsStartedCount: 0,
      cliExecutionsRunningCount: 0,
      cliExecutions: [:],
      appCPUPercent: 0,
      childrenCPUPercent: 0,
      appMemory: 0,
      terminalMemory: 0,
      childrenMemory: 0,
      stateReports: reports,
    )
    let timed = DebugTimelineSlot(samples: [sample])

    #expect(DebugMetric.stateReports.detailText(of: timed) == "Handled in 4 ms mean, 6 ms slowest")
  }

  @Test func everyBandIsNamedInItsTilesLegend() {
    for metric in DebugMetric.allCases {
      for series in metric.series {
        #expect(!series.title.isEmpty, "\(metric) \(series)")
      }
    }
  }
}
