import MultishellCore
import SwiftUI

/// A panel's own header over the detail area, as tall as the title-bar band:
/// its name, a one-line summary and its controls; see `UIMetrics.headerHeight`.
struct PanelHeader<Controls: View>: View {
  let title: String
  let summary: String
  let summaryColor: Color
  let theme: Theme
  let metrics: UIMetrics
  @ViewBuilder let controls: () -> Controls

  var body: some View {
    HStack(spacing: 8) {
      Text(title)
        .font(metrics.font(size: metrics.bodySize, weight: .semibold))
        .foregroundStyle(theme.header.text)
      Text(summary)
        .font(metrics.font(size: metrics.caption))
        .foregroundStyle(summaryColor)
        .lineLimit(1)
        .truncationMode(.tail)
      Spacer(minLength: 8)
      controls()
    }
    .windowHeader(fill: theme.header.background)
  }
}
