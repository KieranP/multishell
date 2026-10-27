import MultishellAppCore
import MultishellCore
import SwiftUI

/// A pull request's state as one glyph: its shape, the colour of its review
/// or state, and a dot on its corner for a conflict or auto-merge.
struct PullRequestGlyph: View {
  let mark: PullRequestMark
  let theme: Theme
  /// What it is drawn on, whose greys the neutral states take.
  let palette: AreaPalette
  let size: Double

  /// One of the design's 16 units at this size.
  private var unit: Double { size / 16 }

  var body: some View {
    ZStack(alignment: .topLeading) {
      PullRequestShape(shape: mark.shape)
        .stroke(
          theme.color(for: mark.tone, on: palette),
          style: StrokeStyle(
            lineWidth: max(1, 1.5 * unit),
            lineCap: .round,
            lineJoin: .round,
            dash: mark.shape == .draft ? [2 * unit, 2 * unit] : [],
          ),
        )
      if let corner = mark.corner {
        // A ring cut from the strokes under the dot, whatever it is drawn on.
        cornerDot(radius: 3.1).blendMode(.destinationOut)
        cornerDot(radius: 2.6).foregroundStyle(theme.color(for: corner))
      }
    }
    .frame(width: size, height: size)
    .compositingGroup()
  }

  /// Centred where the design puts it, inside the glyph's top-right corner.
  private func cornerDot(radius: Double) -> some View {
    Circle()
      .frame(width: 2 * radius * unit, height: 2 * radius * unit)
      .offset(x: (13 - radius) * unit, y: (3 - radius) * unit)
  }
}
