import MultishellCore
import MultishellServices
import SwiftUI

/// A CI run's, workflow's or job's status as the design's glyph in its theme
/// colour.
struct CIRunGlyph: View {
  let status: CIRunStatus
  let theme: Theme
  let palette: AreaPalette
  let size: Double

  @Environment(\.accessibilityReduceMotion) private var reducesMotion

  var body: some View {
    let color = theme.color(for: status, on: palette)
    let lineWidth = UIMetrics.statusGlyphLineWidth(side: size)
    Group {
      if status == .running, !reducesMotion {
        SpinningRunRing(color: color, lineWidth: lineWidth)
      } else {
        CIRunShape(status: status)
          .stroke(
            color,
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round),
          )
      }
    }
    .frame(width: size, height: size)
    // Its callers say the status in words of their own.
    .accessibilityHidden(true)
  }
}
