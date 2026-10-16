import MultishellCore
import SwiftUI

/// What a column holds, under a hairline at its foot: the sidebar's counts and
/// the Files panel's, one height and one caption between them.
struct PanelFooter<Accessory: View>: View {
  private static var height: Double { 30 }

  let text: String
  let theme: Theme
  let metrics: UIMetrics
  @ViewBuilder let accessory: () -> Accessory

  var body: some View {
    HStack(spacing: 8) {
      Text(text)
        .font(metrics.font(size: metrics.caption))
        .foregroundStyle(theme.textTertiary)
        .lineLimit(1)
      accessory()
      Spacer(minLength: 0)
    }
    .padding(.horizontal, UIMetrics.panelSideInset)
    .frame(height: Self.height)
    .hairline(.top, theme)
  }
}

extension PanelFooter where Accessory == EmptyView {
  init(text: String, theme: Theme, metrics: UIMetrics) {
    self.init(text: text, theme: theme, metrics: metrics) { EmptyView() }
  }
}
