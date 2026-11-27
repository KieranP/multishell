import MultishellCore
import SwiftUI

/// The one row a debug table shows while it has nothing to list.
struct DebugTableEmptyRow: View {
  let text: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(text)
      .font(metrics.font(size: metrics.secondary))
      .foregroundStyle(theme.debugInfo.textTertiary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .debugTableRow(theme, verticalPadding: 6)
  }
}
