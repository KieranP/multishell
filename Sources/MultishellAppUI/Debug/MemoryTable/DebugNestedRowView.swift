import MultishellAppCore
import MultishellCore
import SwiftUI

/// A line under an expanded Memory by tab row, a tab's Terminal or a process,
/// indented by its level, its Self and Total under the columns.
struct DebugNestedRowView: View {
  let name: String
  let namesAProcess: Bool
  let indentLevel: Int
  let memory: any DebugSelfAndTotalMemory
  let accessibilityLabel: String
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  /// Under its tab's title, so the rows read as that tab's.
  private static let indent = 14.0
  private static let indentPerLevel = 14.0

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      nameCell
      switch layout {
      case .columns:
        Color.clear.frame(width: metrics.debugCountColumnWidth, height: 1)
        DebugNumberCell(
          text: memory.selfMemoryText, width: metrics.debugMemoryValueColumnWidth,
          color: theme.textSecondary)
        DebugNumberCell(
          text: memory.totalMemoryText, width: metrics.debugMemoryBarColumnWidth,
          color: theme.textSecondary)
      case .stacked:
        Text(memory.memorySummary).monospacedDigit()
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
    .accessibilityLabel(accessibilityLabel)
  }

  private var nameCell: some View {
    HStack(alignment: .firstTextBaseline, spacing: 4) {
      if indentLevel > 0 {
        Image(systemName: "arrow.turn.down.right")
          .font(.system(size: metrics.debugTableGlyphSize))
          .foregroundStyle(theme.textTertiary)
      }
      Text(name)
        .font(.system(size: metrics.caption, design: namesAProcess ? .monospaced : .default))
    }
    .padding(.leading, Self.indent + Double(indentLevel) * Self.indentPerLevel)
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
