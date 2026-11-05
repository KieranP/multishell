import SwiftUI

/// A white glyph centred on a coloured rounded square: a sidebar page's tile
/// and the scope card's.
struct SettingsTile<Glyph: View>: View {
  let side: Double
  let radius: Double
  let color: Color
  @ViewBuilder let glyph: () -> Glyph

  var body: some View {
    glyph()
      .foregroundStyle(.white)
      .frame(width: side, height: side)
      .background(color, in: .rect(cornerRadius: radius))
  }
}
