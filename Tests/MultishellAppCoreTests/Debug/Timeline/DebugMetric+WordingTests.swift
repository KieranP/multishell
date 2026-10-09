import Testing

@testable import MultishellAppCore

@Suite
struct DebugMetricWordingTests {
  private let slot = DebugTimelineSlot(samples: [
    DebugSample.sample(
      sequence: 0,
      framesPerSecond: nil,
      gitRunsStartedCount: 3,
      appCPUPercent: 10,
      childrenCPUPercent: 25,
      terminalMemory: 150,
    )
  ])

  @Test func aSplitStripSaysTheAppsShareUnderItsTotal() {
    #expect(DebugMetric.cpu.valueText(of: slot) == "35%")
    #expect(DebugMetric.cpu.detailText(of: slot) == "App 10% · Child processes 25%")
    #expect(
      DebugMetric.memory.detailText(of: slot)
        == "App \(DebugValueText.memory(250)) · Terminals \(DebugValueText.memory(150)) · "
        + "Child processes \(DebugValueText.memory(1_000))"
    )
  }

  @Test func aStripWithNoReadingOrNothingRunningSaysSo() {
    #expect(DebugMetric.frameRate.valueText(of: slot) == "–")
    #expect(DebugMetric.gitRuns.valueText(of: slot) == "3/s")
    #expect(DebugMetric.gitRuns.detailText(of: slot) == nil, "no git still running")
  }

  @Test func everyStripSaysNoValueBeforeItsFirstSample() {
    for metric in DebugMetric.allCases {
      #expect(metric.valueText(of: nil) == "–", "\(metric)")
    }
  }

  @Test func gitStillRunningAtTheSampleIsCountedUnderTheRate() {
    let running = DebugTimelineSlot(samples: [.sample(sequence: 0, gitRunningCount: 2)])
    #expect(DebugMetric.gitRuns.detailText(of: running) == "2 running")
  }

  @Test func onlyTheFrameRateIsColouredByHowSmoothTheSlotWas() {
    let stalled = DebugTimelineSlot(samples: [
      .sample(sequence: 0, longestFrame: .milliseconds(150))
    ])
    #expect(DebugMetric.frameRate.valueSmoothness(of: stalled) == .stalled)
    #expect(DebugMetric.frameRate.valueSmoothness(of: nil) == nil)
    for metric in DebugMetric.allCases where metric != .frameRate {
      #expect(metric.valueSmoothness(of: stalled) == nil, "\(metric)")
    }
  }
}
