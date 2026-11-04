import SwiftUI

extension View {
  func glyphHover(
    _ isHovered: Bool,
    palette: AreaPalette,
    resting: Color,
    lit: Color? = nil,
    inset: Double = 0,
  ) -> some View {
    modifier(
      GlyphHoverModifier(
        isHovered: isHovered,
        palette: palette,
        resting: resting,
        lit: lit,
        inset: inset,
      )
    )
  }
}
