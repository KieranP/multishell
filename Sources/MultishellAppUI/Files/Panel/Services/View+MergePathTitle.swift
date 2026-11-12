import MultishellCore
import SwiftUI

extension View {
  /// A merge path stop's title, a step's or the end's, wrapping at the panel's width.
  func mergePathTitle(metrics: UIMetrics, theme: Theme) -> some View {
    font(metrics.font(size: metrics.secondary, weight: .semibold))
      .foregroundStyle(theme.filesPanel.text)
      .fixedSize(horizontal: false, vertical: true)
  }
}
