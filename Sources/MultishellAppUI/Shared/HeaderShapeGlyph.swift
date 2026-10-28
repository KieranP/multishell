import SwiftUI

/// The design's own strokes in a window header's button, a point over a
/// symbol's size, as a stroke reads lighter than a glyph of the font.
struct HeaderShapeGlyph<Glyph: Shape>: View {
  private static var lineWidth: Double { 1.3 }
  private static var side: Double { UIMetrics.headerGlyphSize + 1 }

  let shape: Glyph

  var body: some View {
    shape
      .stroke(style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round))
      .frame(width: Self.side, height: Self.side)
      .accessibilityHidden(true)
  }
}
