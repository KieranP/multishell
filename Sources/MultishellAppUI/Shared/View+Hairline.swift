import MultishellCore
import SwiftUI

extension View {
  /// The theme's hairline along one edge, top or bottom.
  func hairline(_ edge: VerticalEdge, _ theme: Theme) -> some View {
    overlay(alignment: edge == .top ? .top : .bottom) {
      theme.hairline.frame(height: UIMetrics.hairlineThickness)
    }
  }
}
