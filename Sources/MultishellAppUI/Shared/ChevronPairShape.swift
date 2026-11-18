import SwiftUI

/// Two chevrons one above the other in the design's 16-unit square: meeting in
/// the middle to collapse, or parting to expand.
struct ChevronPairShape: Shape {
  let pointsInward: Bool

  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    let (topTip, topEnds) = pointsInward ? (7.0, 3.0) : (3.0, 7.0)
    let (bottomTip, bottomEnds) = pointsInward ? (9.0, 13.0) : (13.0, 9.0)
    var path = Path()
    path.move(to: grid.point(4, topEnds))
    path.addLine(to: grid.point(8, topTip))
    path.addLine(to: grid.point(12, topEnds))
    path.move(to: grid.point(4, bottomEnds))
    path.addLine(to: grid.point(8, bottomTip))
    path.addLine(to: grid.point(12, bottomEnds))
    return path
  }
}
