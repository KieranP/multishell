import MultishellCore
import SwiftUI

/// The well's clear glyph, shown while there is text to clear.
struct ClearFilterButton: View {
  let help: String
  let palette: AreaPalette
  let metrics: UIMetrics
  let clear: () -> Void

  var body: some View {
    PlainGlyphButton(help: help, action: clear) {
      Image(systemName: "xmark.circle.fill")
        .font(metrics.font(size: metrics.glyph))
        .foregroundStyle(palette.textTertiary)
        .accessibilityHidden(true)
    }
  }
}
