import MultishellAppCore
import SwiftUI

/// A point placed across a strip `height` points tall, its fractions measured up from the bottom.
struct DebugStripPosition {
  let x: Double
  let point: DebugStripPoint
  let height: Double

  func y(_ boundary: DebugStripLayer.Boundary) -> Double {
    height - boundary.fraction(of: point) * height
  }
}
