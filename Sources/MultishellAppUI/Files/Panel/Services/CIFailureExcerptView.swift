import MultishellCore
import SwiftUI

/// What a failed run's report says, in the terminal's colours, selectable.
struct CIFailureExcerptView: View {
  let text: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Text(text)
      .font(.system(size: metrics.badge, design: .monospaced))
      .foregroundStyle(theme.filesPanel.textSecondary)
      .textSelection(.enabled)
      .padding(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(
        theme.terminalBackground,
        in: RoundedRectangle(cornerRadius: UIMetrics.rowCornerRadius),
      )
      .padding(.horizontal, UIMetrics.servicePageSideInset)
      .padding(.vertical, 6)
  }
}
