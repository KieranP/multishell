import MultishellAppCore
import SwiftUI

/// The pointer's line down a strip, over its chart rather than in it, so a
/// hover redraws this line and not the chart under it.
struct DebugStripPointer: View {
  let slotIndex: Int?
  let timeline: DebugTimeline
  let color: Color

  var body: some View {
    Canvas { context, size in
      guard let slotIndex else { return }
      let x = timeline.slotMidpointX(slotIndex, chartWidth: size.width)
      context.fill(
        Path(CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)), with: .color(color))
    }
    .allowsHitTesting(false)
  }
}
