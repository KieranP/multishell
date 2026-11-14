import SwiftUI

/// A hand-drawn glyph on an All changes button, stroked as the mockups drew it.
struct AllChangesStrokedGlyph<Outline: Shape>: View {
  let outline: Outline
  let metrics: UIMetrics

  var body: some View {
    outline
      .stroke(
        style: StrokeStyle(
          lineWidth: metrics.allChangesGlyphLineWidth,
          lineCap: .round,
          lineJoin: .round,
        )
      )
      .frame(width: metrics.allChangesGlyphSide, height: metrics.allChangesGlyphSide)
  }
}
