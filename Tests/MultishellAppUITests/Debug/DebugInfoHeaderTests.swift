import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI
@testable import MultishellCore

@Suite @MainActor
struct DebugInfoHeaderTests {
  private func pixels(of theme: Theme) throws -> NSBitmapImageRep {
    let harness = ModelHarness()
    let header = DebugInfoHeader(
      model: harness.model,
      timeline: harness.model.debugTimeline(for: .oneMinute),
      range: .constant(.oneMinute),
      theme: theme,
      metrics: harness.model.metrics,
    )
    return try #require(
      OffscreenWindow.pixels(ofHosted: header, size: CGSize(width: 520, height: 44))
    )
  }

  @Test func theSelectedRangeSitsOnTheHeadersSelectionBackground() throws {
    let theme = try MagentaTheme.with([.header: [.selectionBackground]])

    #expect(MagentaTheme.pixelCount(in: try pixels(of: theme)) > 10)
  }

  @Test func pauseIsDrawnOnTheHeadersFill() throws {
    let theme = try MagentaTheme.with([.header: [.fill]])
    let bitmap = try pixels(of: theme)

    #expect(MagentaTheme.pixelCount(in: bitmap, fromX: bitmap.pixelsWide * 7 / 8) > 10)
  }
}
