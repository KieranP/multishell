import MultishellAppCore
import SwiftUI

/// A pull request's glyph as the design's strokes in a 16-unit square, scaled
/// to the frame: two commits joined, the head's line ending as its state says.
struct PullRequestShape: Shape {
  let shape: PullRequestMark.Shape

  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    let unit = grid.unit
    func circle(_ x: Double, _ y: Double) -> CGRect {
      CGRect(
        origin: grid.point(x - 1.8, y - 1.8),
        size: CGSize(width: 3.6 * unit, height: 3.6 * unit),
      )
    }
    var path = Path()
    path.addEllipse(in: circle(4, 3.5))
    path.addEllipse(in: circle(4, 12.5))
    path.move(to: grid.point(4, 5.3))
    path.addLine(to: grid.point(4, 10.7))
    switch shape {
    case .open, .draft:
      path.addEllipse(in: circle(12, 12.5))
      path.move(to: grid.point(12, 10.7))
      path.addLine(to: grid.point(12, 6.5))
      path.addArc(
        tangent1End: grid.point(12, 4),
        tangent2End: grid.point(9.5, 4),
        radius: 2.5 * unit,
      )
      path.addLine(to: grid.point(7, 4))
      path.move(to: grid.point(8.6, 2.4))
      path.addLine(to: grid.point(7, 4))
      path.addLine(to: grid.point(8.6, 5.6))

    case .closed:
      path.addEllipse(in: circle(12, 12.5))
      path.move(to: grid.point(12, 10.7))
      path.addLine(to: grid.point(12, 8.2))
      path.move(to: grid.point(10, 2))
      path.addLine(to: grid.point(14, 6))
      path.move(to: grid.point(14, 2))
      path.addLine(to: grid.point(10, 6))

    case .merged:
      path.addEllipse(in: circle(12, 9))
      path.move(to: grid.point(4, 5.3))
      path.addCurve(
        to: grid.point(10.2, 9),
        control1: grid.point(4, 8.2),
        control2: grid.point(6.5, 9),
      )
    }
    return path
  }
}
