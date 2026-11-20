import SwiftUI

/// The sent bubble's paper plane, nose to the upper right. A 16-unit square, scaled.
struct PaperPlaneShape: Shape {
  func path(in rect: CGRect) -> Path {
    let grid = GlyphGrid(fitting: rect)
    var path = Path()
    path.move(to: grid.point(2.5, 7.8))
    path.addLine(to: grid.point(13.5, 2.5))
    path.addLine(to: grid.point(10.8, 13.5))
    path.addLine(to: grid.point(7.8, 8.8))
    path.closeSubpath()
    path.move(to: grid.point(7.8, 8.8))
    path.addLine(to: grid.point(13.5, 2.5))
    return path
  }
}
