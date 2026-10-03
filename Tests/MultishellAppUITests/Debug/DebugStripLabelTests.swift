import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// The label truncates rather than wraps, so its natural width is held to the
/// column, with the widest figures the strips show.
@Suite @MainActor
struct DebugStripLabelTests {
  private let widestSlot = DebugTimelineSlot(samples: [
    DebugSample(
      sequence: 0, takenAt: Date(), elapsed: .seconds(1),
      frameRate: FrameRateReading(framesPerSecond: 120, longestFrame: .milliseconds(9)),
      gitRunsStartedCount: 88, gitRunningCount: 12, gitCommands: [:], appCPUPercent: 188,
      childrenCPUPercent: 788, appMemory: 1_023_400_000, childrenMemory: 15_920_000_000,
      stateReportCount: 88)
  ])

  private func naturalWidth(of metric: DebugMetric, metrics: UIMetrics) -> Double {
    OffscreenWindow.naturalWidth(
      of: DebugStripLabel(
        metric: metric, slot: widestSlot, theme: Theme.builtins[0], metrics: metrics),
      windowSize: CGSize(width: 800, height: 200))
  }

  @Test(arguments: [Appearance.uiFontSizes.lowerBound, 13, Appearance.uiFontSizes.upperBound])
  func everyStripsLabelFitsItsColumnUncut(fontSize: Double) {
    let metrics = UIMetrics(fontSize: fontSize)
    for metric in DebugMetric.allCases {
      let width = naturalWidth(of: metric, metrics: metrics)
      #expect(
        width <= metrics.debugStripLabelWidth,
        "\(metric) needs \(width) of \(metrics.debugStripLabelWidth) at \(fontSize) pt")
    }
  }
}
