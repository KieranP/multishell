import SwiftUI

/// A symbol in a window header's button, the same size in either column.
struct HeaderGlyph: View {
  let symbol: String

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: UIMetrics.headerGlyphSize, weight: .medium))
      .frame(width: UIMetrics.headerGlyphButtonSide, height: UIMetrics.headerGlyphButtonSide)
  }
}
