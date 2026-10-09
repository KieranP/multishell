import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of the Memory by tab table: in columns, or with its numbers stacked
/// under its name where the panel is too narrow for them. Never truncated.
struct DebugMemoryRowView: View {
  let row: DebugMemoryRow
  let disclosure: DebugRowDisclosure
  let toggleExpansion: () -> Void
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      Image(systemName: disclosure == .expanded ? "chevron.down" : "chevron.right")
        .font(.system(size: metrics.debugTableGlyphSize, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
        .opacity(disclosure.isExpandable ? 1 : 0)
        .frame(width: UIMetrics.debugTableChevronWidth)
      switch layout {
      case .columns: columns

      case .stacked:
        DebugStackedRowView(
          captions: row.stackedCaptions,
          theme: theme,
          metrics: metrics,
        ) {
          title
        } headline: {
          totalCell
        }
      }
    }
    .font(.system(size: metrics.secondary, weight: row.isTotal ? .semibold : .regular))
    .fixedSize(horizontal: false, vertical: true)
    .debugTableRow(theme)
    .debugTableRowHighlight(theme)
    .contentShape(.rect)
    .onTapGesture { if disclosure.isExpandable { toggleExpansion() } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugMemoryRow(row, disclosure: disclosure))
    .accessibilityAddTraits(disclosure.isExpandable ? .isButton : [])
    .accessibilityAction { if disclosure.isExpandable { toggleExpansion() } }
  }

  private var title: some View {
    Text(row.title).foregroundStyle(theme.textPrimary)
  }

  private var columns: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      title.frame(maxWidth: .infinity, alignment: .leading)
      Text(row.subtitle)
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      DebugNumberCell(
        text: row.processCountText,
        width: metrics.debugCountColumnWidth,
        color: theme.textPrimary,
      )
      DebugNumberCell(
        text: row.selfMemoryText,
        width: metrics.debugMemoryValueColumnWidth,
        color: theme.textPrimary,
      )
      totalCell
        .frame(width: metrics.debugMemoryBarColumnWidth, alignment: .trailing)
    }
  }

  private var totalCell: some View {
    HStack(spacing: 6) {
      if row.barFraction > 0 {
        Capsule()
          .fill(theme.debugChildrenSeriesColor)
          .frame(width: metrics.debugMemoryBarLength(forFraction: row.barFraction), height: 5)
      }
      Text(row.totalMemoryText)
        .monospacedDigit()
        .foregroundStyle(theme.textPrimary)
    }
  }
}
