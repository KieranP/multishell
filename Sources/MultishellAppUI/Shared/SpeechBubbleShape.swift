import SwiftUI

/// Review's glyph and a file tab's comment count: a rounded bubble with a tail
/// at its lower left. A 16-unit square, scaled.
struct SpeechBubbleShape: Shape {
  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    let corner = 2 * grid.unit
    var path = Path()
    path.move(to: grid.point(4.5, 2.5))
    path.addArc(
      tangent1End: grid.point(13.5, 2.5),
      tangent2End: grid.point(13.5, 11),
      radius: corner,
    )
    path.addArc(
      tangent1End: grid.point(13.5, 11),
      tangent2End: grid.point(2.5, 11),
      radius: corner,
    )
    path.addLine(to: grid.point(7, 11))
    path.addLine(to: grid.point(4.5, 13.5))
    path.addLine(to: grid.point(4.5, 11))
    path.addArc(
      tangent1End: grid.point(2.5, 11),
      tangent2End: grid.point(2.5, 2.5),
      radius: corner,
    )
    path.addArc(
      tangent1End: grid.point(2.5, 2.5),
      tangent2End: grid.point(13.5, 2.5),
      radius: corner,
    )
    path.closeSubpath()
    return path
  }
}
