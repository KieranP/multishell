import SwiftUI

/// A window header's glyph button, lit under the pointer.
struct HeaderGlyphButton: View {
  let symbol: String
  let help: String
  let palette: AreaPalette
  let resting: Color
  /// What it turns to under the pointer; `nil` is the area's text.
  var lit: Color?
  /// Unlit by its click, as a sheet or picker it opens hides the pointer's exit.
  var opensAWindow = false
  let action: () -> Void

  @State private var isHovered = false

  var body: some View {
    PlainGlyphButton(help: help) {
      if opensAWindow { isHovered = false }
      action()
    } glyph: {
      HeaderGlyph(symbol: symbol)
        .glyphHover(isHovered, palette: palette, resting: resting, lit: lit)
    }
    .tracksHover($isHovered)
  }
}
