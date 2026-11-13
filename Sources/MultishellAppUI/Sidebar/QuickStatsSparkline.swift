import SwiftUI

/// A line through fractions of the height, left to right, for the sidebar's
/// quick stats, broken where a value is `nil`.
struct QuickStatsSparkline: Shape {
  let values: [Double?]

  func path(in rect: CGRect) -> Path {
    var path = Path()
    guard values.count > 1 else { return path }
    let step = rect.width / Double(values.count - 1)
    var continuesLine = false
    for (index, value) in values.enumerated() {
      guard let value else {
        continuesLine = false
        continue
      }
      let point = CGPoint(
        x: rect.minX + Double(index) * step,
        y: rect.maxY - value * rect.height,
      )
      if continuesLine { path.addLine(to: point) } else { path.move(to: point) }
      continuesLine = true
    }
    return path
  }
}
