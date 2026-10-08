import AppKit
import SwiftUI
import Testing

@testable import MultishellAppCore
@testable import MultishellAppUI

@Suite @MainActor
struct DebugStripPointerTests {
  private let timeline = DebugTimeline(history: DebugHistory(), range: .oneMinute)
  private let size = CGSize(width: 600, height: 40)

  private func pixels(slotIndex: Int?) -> InkedPixels {
    InkedPixels(
      OffscreenWindow.pixels(
        ofHosted: DebugStripPointer(slotIndex: slotIndex, timeline: timeline, color: .black),
        size: size)!)
  }

  @Test func theLineRunsTheStripsHeightThroughTheMiddleOfItsSlot() throws {
    let drawn = pixels(slotIndex: 30)
    let box = try #require(drawn.box)
    let scale = Double(drawn.bitmap.pixelsWide) / size.width
    let middle = timeline.slotMidpointX(30, chartWidth: size.width) * scale
    #expect(Double(box.minX) >= middle - scale && Double(box.maxX) <= middle + scale)
    #expect(box.height == drawn.bitmap.pixelsHigh)
  }

  @Test func noSlotDrawsNoLine() {
    #expect(pixels(slotIndex: nil).box == nil)
  }
}
