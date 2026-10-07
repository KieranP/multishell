import AppKit
import MultishellCore
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

/// Values truncate rather than wrap, so the widest figures are held to the
/// narrowest sidebar. At 18 pt they need 186.5, so larger sizes truncate.
@Suite @MainActor
struct SidebarQuickStatsTests {
  @Test func theWidestFiguresFitTheNarrowestSidebarAtTheDefaultSize() {
    let harness = ModelHarness()
    harness.model.debugHistory.append(
      DebugSample(
        sequence: 0, takenAt: Date(), elapsed: .seconds(1),
        frameRate: FrameRateReading(framesPerSecond: 120, longestFrame: .milliseconds(9)),
        gitRunsStartedCount: 0, gitRunningCount: 0, gitCommands: [:], appCPUPercent: 234,
        childrenCPUPercent: 1_000, appMemory: 1_023_400_000, childrenMemory: 15_920_000_000,
        stateReportCount: 0))

    let width = OffscreenWindow.naturalWidth(
      of: SidebarQuickStats(
        model: harness.model, theme: Theme.builtins[0], metrics: UIMetrics(fontSize: 13)),
      windowSize: CGSize(width: 400, height: 100))

    #expect(width <= SidebarWidth.minimum, "needs \(width)")
  }
}
