import MultishellAppCore
import MultishellCore
import SwiftUI

/// A titled panel holding a debug table at its full height, never scrolled:
/// it passes its content the layout its width allows.
struct DebugTableBlock<Content: View>: View {
  let title: String
  let caption: String
  let columnsWidthInEms: Double
  let theme: Theme
  let metrics: UIMetrics
  @ViewBuilder let content: (DebugTableLayout) -> Content

  @State private var width = 0.0

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(title)
          .font(metrics.font(size: metrics.secondary, weight: .semibold))
          .foregroundStyle(theme.debugInfo.text)
        Text(caption)
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.debugInfo.textTertiary)
      }
      .padding(.horizontal, UIMetrics.debugTableInset)
      .padding(.top, 8)
      .padding(.bottom, 6)
      content(
        DebugTableLayout.of(
          width: width,
          columnsWidthInEms: columnsWidthInEms,
          fontSize: metrics.bodySize,
        )
      )
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.bottom, 4)
    .columnBackground(theme.color(.blockBackground, in: .debugInfo))
    .onGeometryChange(for: Double.self) { geometry in
      geometry.size.width
    } action: { newWidth in
      width = newWidth
    }
  }
}
