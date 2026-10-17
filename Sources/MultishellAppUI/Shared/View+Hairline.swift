import MultishellCore
import SwiftUI

extension View {
  func hairline(_ edge: VerticalEdge, _ palette: AreaPalette) -> some View {
    overlay(alignment: edge == .top ? .top : .bottom) {
      palette.border.frame(height: UIMetrics.hairlineThickness)
    }
  }
}
