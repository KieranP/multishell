import MultishellAppCore
import MultishellCore
import MultishellServices
import SwiftUI

/// Whether the pull request can merge, and why not, tinted by the answer, with
/// the merge it offers at its trailing end.
struct MergeReadinessBanner: View {
  private static let tintOpacity = 0.12

  let readiness: MergeReadiness
  let action: MergeAction?
  let base: String
  let theme: Theme
  let metrics: UIMetrics
  /// Its action is already running, which a second click would only repeat.
  let isBusy: Bool
  let perform: (MergeAction) -> Void

  var body: some View {
    let tint = theme.color(for: readiness.status, on: theme.filesPanel)
    HStack(spacing: 8) {
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
      }
      .accessibilityElement(children: .combine)
      Spacer(minLength: 0)
      if let action {
        Button(action.title) { perform(action) }
          .controlSize(.small)
          .disabled(isBusy)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 9)
    .background(
      tint.opacity(Self.tintOpacity),
      in: RoundedRectangle(cornerRadius: UIMetrics.columnCornerRadius),
    )
    .padding(.horizontal, UIMetrics.servicePageSideInset)
    .padding(.bottom, 6)
  }
}
