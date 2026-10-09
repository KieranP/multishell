import SwiftUI

/// A line through fractions of the height, left to right, for the sidebar's
/// quick stats.
struct QuickStatsSparkline: Shape {
  let values: [Double]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard values.count > 1 else { return path }
    let step = rect.width / Double(values.count - 1)
    for (index, value) in values.enumerated() {
      let point = CGPoint(
        x: rect.minX + Double(index) * step,
        y: rect.maxY - value * rect.height,
      )
      if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
    }
    return path
  }
}
