import SwiftUI

/// A motion's glyph held still, from the path `AnimatedGlyphView` strokes, so
/// Reduce Motion draws the same arc the moving one does.
struct StillGlyphShape: Shape {
  let motion: GlyphMotion
  let lineWidth: Double

  func path(in rect: CGRect) -> Path {
    Path(motion.path(in: rect, lineWidth: lineWidth))
  }
}
