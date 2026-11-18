import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// Values truncate rather than wrap, so the widest figures are held to the
/// narrowest sidebar. At 18 pt they need 242, so larger sizes truncate.
@Suite @MainActor
struct SidebarQuickStatsTests {
  @Test func theWidestFiguresFitTheNarrowestSidebarAtTheDefaultSize() {
    let harness = ModelHarness()
    var widest = DebugSample(
      sequence: 0,
      takenAt: Date(),
      elapsed: .seconds(1),
      frameRate: FrameRateReading(framesPerSecond: 120, longestFrame: .milliseconds(9)),
      cliExecutionsStartedCount: 0,
      cliExecutionsRunningCount: 0,
      cliExecutions: [:],
      appCPUPercent: 234,
      childrenCPUPercent: 1_000,
      appMemory: 1_023_400_000,
      terminalMemory: 0,
      childrenMemory: 15_920_000_000,
      stateReports: .empty,
    )
    widest.activity = DebugActivityCounts(
      diskBytesRead: 0,
      diskBytesWritten: 1_073_000_000,
      interruptWakeups: 0,
      packageIdleWakeups: 0,
    )
    harness.model.debugHistory.append(widest)

    let width = OffscreenWindow.naturalWidth(
      of: SidebarQuickStats(
        model: harness.model,
        theme: Theme.builtins[0],
        metrics: UIMetrics(fontSize: 13, fontFamily: nil),
      ),
      windowSize: CGSize(width: 400, height: 100),
    )

    #expect(width <= SidebarWidth.minimum, "needs \(width)")
  }
}
