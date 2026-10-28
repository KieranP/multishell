import MultishellCore
import SwiftUI

/// A line under a services' page's list saying why it may be out of date.
struct PanelNote: View {
  let text: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(text)
      .font(metrics.font(size: metrics.caption))
      .foregroundStyle(theme.filesPanel.textTertiary)
      .fixedSize(horizontal: false, vertical: true)
      .padding(.horizontal, UIMetrics.servicePageSideInset)
      .padding(.top, 6)
  }
}
