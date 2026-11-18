import MultishellAppCore
import SwiftUI

/// The pointer's line down a chart, laid over it rather than drawn in it, so a
/// hover redraws this line and not the chart under it.
struct DebugStripPointer: View {
  let slotIndex: Int?
  let timeline: DebugTimeline
  let color: Color

  var body: some View {
    GeometryReader { proxy in
      if let slotIndex {
        color
          .frame(width: 1)
          .offset(x: timeline.slotMidpointX(slotIndex, chartWidth: proxy.size.width) - 0.5)
      }
    }
    .allowsHitTesting(false)
  }
}
