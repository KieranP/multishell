import MultishellAppCore
import MultishellCore
import SwiftUI

/// A nested row under an expanded Memory Breakdown row, a part of the app, a tab's
/// Terminal or a process, indented by its level, its Self and Total under the columns.
struct DebugNestedRowView: View {
  let name: String
  let namesAProcess: Bool
  let indentLevel: Int
  let memory: any DebugSelfAndTotalMemory
  let accessibilityLabel: String
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      DebugNestedRowName(
        name: name,
        isMonospaced: namesAProcess,
        indentLevel: indentLevel,
        theme: theme,
        metrics: metrics,
      )
      .frame(maxWidth: .infinity, alignment: .leading)
      switch layout {
      case .columns:
        Color.clear.frame(width: metrics.debugCountColumnWidth, height: 1)
        DebugNumberCell(
          text: memory.selfMemoryText,
          width: metrics.debugMemoryValueColumnWidth,
          color: theme.debugInfo.textSecondary,
        )
        DebugNumberCell(
          text: memory.totalMemoryText,
          width: metrics.debugMemoryBarColumnWidth,
          color: theme.debugInfo.textSecondary,
        )

      case .stacked:
        Text(memory.memorySummary).monospacedDigit()
      }
    }
    .font(metrics.font(size: metrics.caption))
    .foregroundStyle(theme.debugInfo.textSecondary)
    .fixedSize(horizontal: false, vertical: true)
    .padding(.leading, UIMetrics.debugTableTitleInset)
    .padding(.trailing, UIMetrics.debugTableInset)
    .padding(.vertical, 2)
    .debugTableRowHighlight(theme)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
  }
}
