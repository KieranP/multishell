import MultishellCore
import SwiftUI

extension View {
  func hoverTooltip(_ text: String, palette: AreaPalette, metrics: UIMetrics) -> some View {
    modifier(HoverTooltipModifier(text: text, palette: palette, metrics: metrics))
  }
}
