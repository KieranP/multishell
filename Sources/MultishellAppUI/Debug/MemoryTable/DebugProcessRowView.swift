import MultishellAppCore
import MultishellCore
import SwiftUI

/// One process under an expanded row of the Memory by tab table, indented
/// under the process that started it, its Self and Total under the columns.
struct DebugProcessRowView: View {
  let row: DebugProcessRow
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  /// Under its tab's title, so the rows read as that tab's.
  private static let indent = 14.0
  private static let indentPerDepth = 14.0

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      name
      switch layout {
      case .columns:
        Color.clear.frame(width: metrics.debugCountColumnWidth, height: 1)
        DebugNumberCell(
          text: row.selfMemoryText, width: metrics.debugMemoryValueColumnWidth,
          color: theme.textSecondary)
        DebugNumberCell(
          text: row.totalMemoryText, width: metrics.debugMemoryBarColumnWidth,
          color: theme.textSecondary)
      case .stacked:
        Text(row.memorySummary).monospacedDigit()
      }
    }
    .font(.system(size: metrics.caption))
    .foregroundStyle(theme.textSecondary)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.leading, UIMetrics.debugTableTitleInset)
    .padding(.trailing, UIMetrics.debugTableInset)
    .padding(.vertical, 2)
    .debugTableRowHighlight(theme)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(AccessibilityText.debugProcessRow(row))
  }

  private var name: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      if row.depth > 0 {
        Image(systemName: "arrow.turn.down.right")
          .font(.system(size: metrics.debugTableGlyphSize))
          .foregroundStyle(theme.textTertiary)
      }
      Text(row.process.name).font(.system(size: metrics.caption, design: .monospaced))
    }
    .padding(.leading, Self.indent + Double(row.depth) * Self.indentPerDepth)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
