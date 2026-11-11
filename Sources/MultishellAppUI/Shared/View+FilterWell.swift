import MultishellCore
import SwiftUI

extension View {
  func filterWell(palette: AreaPalette, metrics: UIMetrics, listSideInset: Double) -> some View {
    modifier(FilterWellModifier(palette: palette, metrics: metrics, listSideInset: listSideInset))
  }
}
