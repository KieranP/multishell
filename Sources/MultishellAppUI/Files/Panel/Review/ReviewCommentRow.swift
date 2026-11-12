import MultishellAppCore
import MultishellCore
import SwiftUI

/// One comment in Review, its text cut to two lines: a click opens its card, and
/// its menu deletes it; see files/review-comments.md.
struct ReviewCommentRow: View {
  let row: ReviewRow
  let theme: Theme
  let metrics: UIMetrics
  let select: () -> Void
  let remove: () -> Void

  var body: some View {
    Button(action: select) {
      VStack(alignment: .leading, spacing: 3) {
        HStack(spacing: 6) {
          Text(row.lineLabel)
            .font(.system(size: metrics.caption, design: .monospaced))
            .foregroundStyle(theme.filesPanel.textSecondary)
          if let scopeNote = row.scopeNote {
            Text(scopeNote)
              .font(metrics.font(size: metrics.caption))
              .foregroundStyle(theme.filesPanel.textTertiary)
          }
          Spacer(minLength: 4)
          ReviewChipLabel(
            chip: row.chip,
            palette: theme.filesPanel,
            theme: theme,
            metrics: metrics,
          )
        }
        Text(row.text)
          .font(metrics.font(size: metrics.secondary))
          .foregroundStyle(theme.filesPanel.text)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
      }
      .padding(.vertical, 6)
      .padding(.leading, UIMetrics.panelSideInset + metrics.reviewCommentIndent)
      .padding(.trailing, UIMetrics.panelSideInset)
      .frame(maxWidth: .infinity, alignment: .leading)
      .contentShape(.rect)
    }
    .buttonStyle(.plain)
    .rowSelection(theme.filesPanel, isSelected: row.isSelected)
    .accessibilityElement(children: .combine)
    .selectableButtonTraits(isSelected: row.isSelected)
    .accessibilityAction(named: row.chip.removeTitle, remove)
    .contextMenu {
      Button(row.chip.removeTitle, action: remove)
    }
  }
}
