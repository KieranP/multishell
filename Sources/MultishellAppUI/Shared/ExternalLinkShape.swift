import SwiftUI

/// The design's open-on-the-site glyph in a 16-unit square, scaled: an arrow
/// leaving the corner of a box.
struct ExternalLinkShape: Shape {
  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    let unit = grid.unit
    let corner = 0.5 * unit
    var path = Path()
    path.move(to: grid.point(9, 2.5))
    path.addLine(to: grid.point(13.5, 2.5))
    path.addLine(to: grid.point(13.5, 7))
    path.move(to: grid.point(13.5, 2.5))
    path.addLine(to: grid.point(7.5, 8.5))
    path.move(to: grid.point(12, 9.5))
    path.addArc(
      tangent1End: grid.point(12, 13.5),
      tangent2End: grid.point(2.5, 13.5),
      radius: corner,
    )
    path.addArc(
      tangent1End: grid.point(2.5, 13.5),
      tangent2End: grid.point(2.5, 4),
      radius: corner,
    )
    path.addArc(tangent1End: grid.point(2.5, 4), tangent2End: grid.point(6.5, 4), radius: corner)
    path.addLine(to: grid.point(6.5, 4))
    return path
  }
}
