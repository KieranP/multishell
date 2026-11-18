import SwiftUI

/// A glyph button of the All changes tab's bar or a file's header: a square
/// hit target, lit under the pointer as the app's other glyph buttons are.
struct AllChangesGlyphButton<Glyph: View>: View {
  let help: String
  let palette: AreaPalette
  /// The lit square; `nil` is the area's fill.
  var litFill: Color?
  let action: () -> Void
  @ViewBuilder let glyph: () -> Glyph

  @State private var isHovered = false

  var body: some View {
    PlainGlyphButton(help: help, action: action) {
      glyph()
        .accessibilityHidden(true)
        .frame(
          width: UIMetrics.allChangesGlyphButtonSide,
          height: UIMetrics.allChangesGlyphButtonSide,
        )
        .glyphHover(
          isHovered,
          palette: palette,
          resting: palette.textSecondary,
          litFill: litFill,
        )
    }
    .tracksHover($isHovered)
  }
}
