import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// Whether the pull request can merge, and why not, tinted by the answer.
struct MergeReadinessBanner: View {
  private static let tintOpacity = 0.12

  let readiness: MergeReadiness
  let base: String
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    let tint = theme.color(for: readiness.status, on: theme.filesPanel)
    HStack(spacing: 8) {
      CIRunGlyph(
        status: readiness.status,
        theme: theme,
        palette: theme.filesPanel,
        size: metrics.glyph,
      )
      VStack(alignment: .leading, spacing: 1) {
        Text(readiness.title(base: base))
          .font(metrics.font(size: metrics.secondary, weight: .semibold))
          .foregroundStyle(theme.filesPanel.text)
        if let detail = readiness.detail(base: base) {
          Text(detail)
            .font(metrics.font(size: metrics.caption))
            .foregroundStyle(theme.filesPanel.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 9)
    .background(
      tint.opacity(Self.tintOpacity),
      in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius),
    )
    .padding(.horizontal, UIMetrics.servicePageSideInset)
    .padding(.bottom, 6)
    .accessibilityElement(children: .combine)
  }
}
