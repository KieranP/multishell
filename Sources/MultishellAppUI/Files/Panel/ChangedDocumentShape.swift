import SwiftUI

/// The Changes tab's glyph: a page with a plus over a minus, so it reads apart
/// from the pull request's two joined commits. A 16-unit square, scaled.
struct ChangedDocumentShape: Shape {
  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    let unit = grid.unit
    var path = Path()
    let corner = 1.5 * unit
    path.move(to: grid.point(4, 1.5))
    path.addLine(to: grid.point(9.5, 1.5))
    path.addLine(to: grid.point(12.5, 4.5))
    path.addArc(
      tangent1End: grid.point(12.5, 14.5),
      tangent2End: grid.point(2.5, 14.5),
      radius: corner,
    )
    path.addArc(
      tangent1End: grid.point(2.5, 14.5),
      tangent2End: grid.point(2.5, 1.5),
      radius: corner,
    )
    path.addArc(
      tangent1End: grid.point(2.5, 1.5),
      tangent2End: grid.point(4, 1.5),
      radius: corner,
    )
    path.closeSubpath()
    path.move(to: grid.point(7.5, 5))
    path.addLine(to: grid.point(7.5, 9))
    path.move(to: grid.point(5.5, 7))
    path.addLine(to: grid.point(9.5, 7))
    path.move(to: grid.point(5.5, 11.5))
    path.addLine(to: grid.point(9.5, 11.5))
    return path
  }
}
