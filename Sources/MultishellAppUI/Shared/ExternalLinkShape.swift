import SwiftUI

/// The design's open-on-the-site glyph in a 16-unit square, scaled: an arrow
/// leaving the corner of a box.
struct ExternalLinkShape: Shape {
  func path(in rect: CGRect) -> Path {
    let unit = min(rect.width, rect.height) / 16
    func point(_ x: Double, _ y: Double) -> CGPoint {
      CGPoint(x: rect.minX + x * unit, y: rect.minY + y * unit)
    }
    let corner = 0.5 * unit
    var path = Path()
    path.move(to: point(9, 2.5))
    path.addLine(to: point(13.5, 2.5))
    path.addLine(to: point(13.5, 7))
    path.move(to: point(13.5, 2.5))
    path.addLine(to: point(7.5, 8.5))
    path.move(to: point(12, 9.5))
    path.addArc(tangent1End: point(12, 13.5), tangent2End: point(2.5, 13.5), radius: corner)
    path.addArc(tangent1End: point(2.5, 13.5), tangent2End: point(2.5, 4), radius: corner)
    path.addArc(tangent1End: point(2.5, 4), tangent2End: point(6.5, 4), radius: corner)
    path.addLine(to: point(6.5, 4))
    return path
  }
}
