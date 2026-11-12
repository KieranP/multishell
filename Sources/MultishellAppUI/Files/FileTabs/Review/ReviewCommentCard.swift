import MultishellAppCore
import MultishellCore
import SwiftUI

/// A comment under its lines: its lines and state, its text, and Edit and
/// Delete while pending or Dismiss once sent. Stale lines quote what they read.
struct ReviewCommentCard: View {
  let comment: ReviewComment
  let isSelected: Bool
  let theme: Theme
  let metrics: UIMetrics
  let edit: () -> Void
  let remove: () -> Void

  private var chip: ReviewChip { ReviewChip(comment) }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        Text(comment.lineLabel)
          .font(.system(size: metrics.caption, design: .monospaced))
          .foregroundStyle(theme.fileTab.textSecondary)
        ReviewChipLabel(chip: chip, palette: theme.fileTab, theme: theme, metrics: metrics)
        Spacer(minLength: 8)
        if comment.isPending {
          Button(t("review.edit"), action: edit)
        }
        Button(chip.removeTitle, action: remove)
      }
      .buttonStyle(.plain)
      .font(metrics.font(size: metrics.caption))
      .foregroundStyle(theme.fileTab.textSecondary)
      Text(comment.text)
        .font(metrics.font(size: metrics.secondary))
        .foregroundStyle(theme.fileTab.text)
        .fixedSize(horizontal: false, vertical: true)
      if chip.showsQuote {
        Text(t("review.quote-heading"))
          .font(metrics.font(size: metrics.caption))
          .foregroundStyle(theme.fileTab.textTertiary)
        Text(comment.quote.joined(separator: "\n"))
          .font(.system(size: metrics.caption, design: .monospaced))
          .foregroundStyle(theme.fileTab.textSecondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
    .reviewCardFrame(theme: theme, isSelected: isSelected)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(t("review.card", comment.lineLabel, chip.title))
  }
}
