import MultishellCore
import SwiftUI

extension View {
  func filterWell(palette: AreaPalette, metrics: UIMetrics) -> some View {
    modifier(FilterWellModifier(palette: palette, metrics: metrics))
  }
}
