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
          .font(.system(size: metrics.secondary, weight: .semibold))
          .foregroundStyle(theme.textPrimary)
        Text(caption)
          .font(.system(size: metrics.caption))
          .foregroundStyle(theme.textTertiary)
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
    .columnBackground(theme)
    .onGeometryChange(for: Double.self) { geometry in
      geometry.size.width
    } action: { newWidth in
      width = newWidth
    }
  }
}
