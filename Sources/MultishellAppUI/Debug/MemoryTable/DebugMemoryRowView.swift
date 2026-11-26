import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of the Memory Breakdown table: in columns, or with its numbers stacked
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
      DebugDisclosureChevron(disclosure: disclosure, theme: theme, metrics: metrics)
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
    .font(metrics.font(size: metrics.secondary, weight: row.isTotal ? .semibold : .regular))
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
    Text(row.title).foregroundStyle(theme.debugInfo.text)
  }

  private var columns: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      title.frame(maxWidth: .infinity, alignment: .leading)
      Text(row.subtitle)
        .foregroundStyle(theme.debugInfo.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      DebugNumberCell(
        text: row.processCountText,
        width: metrics.debugCountColumnWidth,
        color: theme.debugInfo.text,
      )
      DebugNumberCell(
        text: row.selfMemoryText,
        width: metrics.debugMemoryValueColumnWidth,
        color: theme.debugInfo.text,
      )
      totalCell
    }
  }

  /// The bar and the figure in their own columns, the bar centred on the text.
  private var totalCell: some View {
    HStack(spacing: UIMetrics.debugTableColumnSpacing) {
      Capsule()
        .fill(theme.debugChildrenSeriesColor)
        .frame(width: metrics.debugMemoryBarLength(forFraction: row.barFraction), height: 5)
        .opacity(row.barFraction > 0 ? 1 : 0)
        .frame(width: metrics.debugMemoryBarColumnWidth, alignment: .leading)
      DebugNumberCell(
        text: row.totalMemoryText,
        width: metrics.debugMemoryValueColumnWidth,
        color: theme.debugInfo.text,
      )
    }
  }
}
