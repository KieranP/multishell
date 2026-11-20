import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of CPU Breakdown, a group or a name under it: in columns, or with its
/// numbers stacked under its title where the panel is too narrow for them.
struct DebugThreadRowView: View {
  let row: any DebugThreadFigures
  /// Whose band colour a group's square takes; a name under it shows none.
  let group: DebugThreadGroup
  let isNested: Bool
  let disclosure: DebugRowDisclosure
  let toggleExpansion: () -> Void
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      DebugDisclosureChevron(disclosure: disclosure, theme: theme, metrics: metrics)
      switch layout {
      case .columns:
        name.frame(maxWidth: .infinity, alignment: .leading)
        number(row.threadCountText, width: metrics.debugCountColumnWidth)
        number(row.meanPercentText, width: metrics.debugDurationColumnWidth)
        number(row.cpuTimeText, width: metrics.debugDurationColumnWidth)

      case .stacked:
        DebugStackedRowView(captions: row.stackedCaptions, theme: theme, metrics: metrics) {
          name
        } headline: {
          Text(row.cpuTimeText).monospacedDigit().foregroundStyle(theme.debugInfo.text)
        }
      }
    }
    .font(metrics.font(size: isNested ? metrics.caption : metrics.secondary))
    .fixedSize(horizontal: false, vertical: true)
    .debugTableRow(theme)
    .debugTableRowHighlight(theme)
    .contentShape(.rect)
    .onTapGesture { if disclosure.isExpandable { toggleExpansion() } }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugThreadRow(row, disclosure: disclosure))
    .accessibilityAddTraits(disclosure.isExpandable ? .isButton : [])
    .accessibilityAction { if disclosure.isExpandable { toggleExpansion() } }
  }

  @ViewBuilder private var name: some View {
    if isNested {
      DebugNestedRowName(
        name: row.title,
        isMonospaced: true,
        indentLevel: 0,
        theme: theme,
        metrics: metrics,
      )
      .foregroundStyle(theme.debugInfo.textSecondary)
    } else {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        RoundedRectangle(cornerRadius: 2)
          .fill(theme.color(for: group.series))
          .frame(width: 7, height: 7)
        Text(row.title).foregroundStyle(theme.debugInfo.text)
      }
    }
  }

  private func number(_ text: String, width: Double) -> some View {
    DebugNumberCell(
      text: text,
      width: width,
      color: isNested ? theme.debugInfo.textSecondary : theme.debugInfo.text,
    )
  }
}
