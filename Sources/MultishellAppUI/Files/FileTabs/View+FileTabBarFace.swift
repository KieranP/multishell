import SwiftUI

extension View {
  /// The bar over a file tab or an All changes tab, which match.
  func fileTabBarFace(palette: AreaPalette, metrics: UIMetrics) -> some View {
    font(metrics.font(size: metrics.secondary))
      .padding(.leading, UIMetrics.fileTabBarLeadingPadding)
      .padding(.trailing, UIMetrics.fileTabBarTrailingPadding)
      .frame(height: UIMetrics.fileTabBarHeight)
      .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
      .clipped()
      .background(palette.background)
      .hairline(.bottom, palette)
  }
}
