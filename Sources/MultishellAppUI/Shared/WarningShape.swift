import SwiftUI

/// The design's warning in a 16-unit square, scaled: a triangle round a mark,
/// the mark's dot a stroke too short to see but for its round caps.
struct WarningShape: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = min(rect.width, rect.height) / 16
    func point(_ x: Double, _ y: Double) -> CGPoint {
      CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }
    var path = Path()
    path.move(to: point(8, 2))
    path.addLine(to: point(14.5, 13.5))
    path.addLine(to: point(1.5, 13.5))
    path.closeSubpath()
    path.move(to: point(8, 6.5))
    path.addLine(to: point(8, 9.5))
    path.move(to: point(8, 11.6))
    path.addLine(to: point(8, 11.7))
    return path
  }
}
