import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of the Memory by tab table: in columns, or with its numbers stacked
/// under its name where the panel is too narrow for them. Never truncated.
struct DebugMemoryRow: View {
  let line: DebugMemoryLine
  let disclosure: DebugRowDisclosure
  let toggle: () -> Void
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      Image(systemName: disclosure == .expanded ? "chevron.down" : "chevron.right")
        .font(.system(size: metrics.small - 1, weight: .semibold))
        .foregroundStyle(theme.textTertiary)
        .opacity(disclosure == .notExpandable ? 0 : 1)
        .frame(width: UIMetrics.debugTableChevronWidth)
      switch layout {
      case .columns: columns
      case .stacked:
        DebugStackedRow(
          captions: line.stackedCaption.map { [$0] } ?? [], theme: theme, metrics: metrics
        ) {
          title
        } headline: {
          totalCell
        }
      }
    }
    .font(.system(size: metrics.secondary, weight: line.isTotal ? .semibold : .regular))
    .fixedSize(horizontal: false, vertical: true)
    .debugTableRow(theme)
    .highlightsOnHover(theme)
    .contentShape(.rect)
    .onTapGesture { if disclosure != .notExpandable { toggle() } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugMemoryLine(line, disclosure: disclosure))
    .accessibilityAddTraits(disclosure == .notExpandable ? [] : .isButton)
    .accessibilityAction { if disclosure != .notExpandable { toggle() } }
  }

  private var title: some View {
    Text(line.title).foregroundStyle(theme.textPrimary)
  }

  private var columns: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      title.frame(maxWidth: .infinity, alignment: .leading)
      Text(line.subtitle)
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      DebugNumberCell(
        text: line.processCountText, width: metrics.debugCountColumnWidth,
        color: theme.textPrimary)
      DebugNumberCell(
        text: line.selfMemoryText, width: metrics.debugMemoryValueColumnWidth,
        color: theme.textPrimary)
      totalCell
        .frame(width: metrics.debugMemoryBarColumnWidth, alignment: .trailing)
    }
  }

  private var totalCell: some View {
    HStack(spacing: 6) {
      if line.barFraction > 0 {
        Capsule()
          .fill(theme.debugChildrenSeriesColor)
          .frame(width: max(2, line.barFraction * metrics.debugMemoryBarWidth), height: 5)
      }
      Text(line.totalMemoryText)
        .monospacedDigit()
        .foregroundStyle(theme.textPrimary)
    }
  }
}
