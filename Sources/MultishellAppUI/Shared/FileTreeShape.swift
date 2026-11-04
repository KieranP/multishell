import SwiftUI

/// The Files tab's glyph: a folder's box with two entries hanging off it, drawn
/// in the strokes of Changes, PR and CI. Not `doc.on.doc`, which is Copy.
struct FileTreeShape: Shape {
  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    var path = Path()
    // Boxes 2.75 units apart, so the strokes keep a gap at the header's 14 pt.
    box(from: (2, 1.5), to: (6.5, 4), on: grid, into: &path)
    path.move(to: grid.point(4.25, 4))
    path.addLine(to: grid.point(4.25, 13.25))
    path.addLine(to: grid.point(7.5, 13.25))
    path.move(to: grid.point(4.25, 8))
    path.addLine(to: grid.point(7.5, 8))
    box(from: (7.5, 6.75), to: (14, 9.25), on: grid, into: &path)
    box(from: (7.5, 12), to: (14, 14.5), on: grid, into: &path)
    return path
  }

  private func box(
    from start: (Double, Double),
    to end: (Double, Double),
    on grid: GlyphGrid,
    into path: inout Path,
  ) {
    let origin = grid.point(start.0, start.1)
    let corner = grid.point(end.0, end.1)
    let radius = 0.9 * grid.unit
    path.addRoundedRect(
      in: CGRect(
        x: origin.x,
        y: origin.y,
        width: corner.x - origin.x,
        height: corner.y - origin.y,
      ),
      cornerSize: CGSize(width: radius, height: radius),
    )
  }
}
