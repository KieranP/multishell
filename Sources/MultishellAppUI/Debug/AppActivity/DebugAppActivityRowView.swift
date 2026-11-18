import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of App Activity: in columns, or with its numbers stacked under its
/// name where the panel is too narrow for them.
struct DebugAppActivityRowView: View {
  let row: DebugAppActivityRow
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Group {
      switch layout {
      case .columns:
        HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
          name.frame(maxWidth: .infinity, alignment: .leading)
          number(row.countText, width: metrics.debugCountColumnWidth)
          number(row.totalDurationText, width: metrics.debugDurationColumnWidth)
          number(row.meanDurationText, width: metrics.debugDurationColumnWidth)
          number(row.slowestDurationText, width: metrics.debugDurationColumnWidth)
          number(row.bytesWrittenText, width: metrics.debugMemoryValueColumnWidth)
        }

      case .stacked:
        DebugStackedRowView(captions: row.stackedCaptions, theme: theme, metrics: metrics) {
          name
        } headline: {
          Text(row.totalDurationText).monospacedDigit().foregroundStyle(theme.debugInfo.text)
        }
      }
    }
    .font(metrics.font(size: metrics.secondary))
    .fixedSize(horizontal: false, vertical: true)
    .debugTableRow(theme)
    .debugTableRowHighlight(theme)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugAppActivityRow(row))
  }

  private var name: some View {
    Text(row.title).foregroundStyle(theme.debugInfo.text)
  }

  private func number(_ text: String, width: Double) -> some View {
    DebugNumberCell(text: text, width: width, color: theme.debugInfo.text)
  }
}
