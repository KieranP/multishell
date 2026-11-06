import MultishellAppCore
import SwiftUI

/// A chrome glyph lit under the pointer as the find bar's are: full text over
/// the area's fill, so it reads as a button. See Docs/design/appearance/window-chrome.md.
struct GlyphHoverModifier: ViewModifier {
  let isHovered: Bool
  let palette: AreaPalette
  let resting: Color
  /// What it turns to under the pointer; `nil` is the area's text.
  let lit: Color?
  /// How far the lit square sits inside the button's frame.
  let inset: Double

  @Environment(\.isEnabled) private var isEnabled

  private var isLit: Bool { GlyphButtonLight.isLit(isHovered: isHovered, isEnabled: isEnabled) }

  func body(content: Content) -> some View {
    content
      .foregroundStyle(isLit ? lit ?? palette.text : resting)
      .background {
        if isLit {
          RoundedRectangle(cornerRadius: UIMetrics.glyphButtonCornerRadius)
            .fill(palette.fill)
            .padding(inset)
        }
      }
  }
}
