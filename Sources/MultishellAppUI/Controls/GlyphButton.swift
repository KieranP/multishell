import SwiftUI

/// A chrome button drawn only by its glyph, in the plain style, its help also
/// what a screen reader says.
struct GlyphButton<Glyph: View>: View {
  let help: String
  let action: () -> Void
  @ViewBuilder let glyph: () -> Glyph

  var body: some View {
    Button(action: action) {
      glyph().contentShape(.rect)
    }
    .buttonStyle(.plain)
    .help(help)
    .accessibilityLabel(help)
  }
}
