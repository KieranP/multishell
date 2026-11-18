import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellProcess

/// A tile's title and value never wrap, so their natural width is held to the
/// label column with the widest figures the tiles show; captions and legends wrap.
@Suite @MainActor
struct DebugTileLabelTests {
  private let widestSlot: DebugTimelineSlot = {
    var sample = DebugSample(
      sequence: 0,
      takenAt: Date(),
      elapsed: .seconds(1),
      frameRate: FrameRateReading(framesPerSecond: 120, longestFrame: .milliseconds(9)),
      cliExecutionsStartedCount: 88,
      cliExecutionsRunningCount: 12,
      cliExecutions: [:],
      appCPUPercent: 188,
      childrenCPUPercent: 788,
      appMemory: 2_146_000_000,
      terminalMemory: 1_073_000_000,
      childrenMemory: 99_900_000_000,
      stateReports: (0..<88).reduce(into: DebugWorkTally.empty) { tally, _ in tally.add(.zero) },
    )
    sample.activity = DebugActivityCounts(
      diskBytesRead: 900_000_000,
      diskBytesWritten: 900_000_000,
      interruptWakeups: 88_888,
      packageIdleWakeups: 8_888,
    )
    sample.memoryPressure = .critical
    sample.peakMemory = 99_900_000_000
    sample.threadCount = 888
    sample.openDescriptorCount = 88_888
    sample.fileEventCount = 888
    return DebugTimelineSlot(samples: [sample])
  }()

  private func naturalWidth(
    of text: String,
    size: Double,
    weight: Font.Weight,
    metrics: UIMetrics,
  )
    -> Double
  {
    OffscreenWindow.naturalWidth(
      of: Text(text).font(metrics.font(size: size, weight: weight)).monospacedDigit(),
      windowSize: CGSize(width: 800, height: 200),
    )
  }

  @Test(arguments: [Appearance.uiFontSizes.lowerBound, 13, Appearance.uiFontSizes.upperBound])
  func everyTilesTitleAndValueFitTheLabelColumnUncut(fontSize: Double) {
    let metrics = UIMetrics(fontSize: fontSize, fontFamily: nil)
    for metric in DebugMetric.allCases {
      let value = naturalWidth(
        of: metric.valueText(of: widestSlot),
        size: metrics.debugTileValueSize,
        weight: .semibold,
        metrics: metrics,
      )
      let title = naturalWidth(
        of: metric.title,
        size: metrics.caption,
        weight: .regular,
        metrics: metrics,
      )
      #expect(
        max(value, title) <= metrics.debugTileLabelWidth,
        "\(metric) needs \(max(value, title)) of \(metrics.debugTileLabelWidth) at \(fontSize) pt",
      )
    }
  }
}
