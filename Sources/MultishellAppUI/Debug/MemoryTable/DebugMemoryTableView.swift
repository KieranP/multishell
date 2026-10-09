import MultishellAppCore
import MultishellCore
import MultishellProcess
import SwiftUI

/// The app, each tab heaviest first, what no tab runs, and the total. A row
/// with processes expands to list them.
struct DebugMemoryTableView: View {
  let table: DebugMemoryTable
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  @State private var expandedSources: Set<DebugMemoryRow.Source> = []

  var body: some View {
    VStack(spacing: 0) {
      if layout == .columns { header }
      ForEach(table.rows) { row in
        let disclosure = row.disclosure(isExpanded: expandedSources.contains(row.source))
        DebugMemoryRowView(
          row: row, disclosure: disclosure, toggleExpansion: { toggleExpansion(of: row.source) },
          layout: layout, theme: theme, metrics: metrics)
        if disclosure == .expanded {
          if let terminal = row.terminalRow {
            DebugNestedRowView(
              name: terminal.title, namesAProcess: false, indentLevel: 0, memory: terminal,
              accessibilityLabel: AccessibilityText.debugTerminalRow(terminal), layout: layout,
              theme: theme, metrics: metrics)
          }
          ForEach(row.processRows) { process in
            DebugNestedRowView(
              name: process.process.name, namesAProcess: true,
              indentLevel: row.indentLevel(of: process), memory: process,
              accessibilityLabel: AccessibilityText.debugProcessRow(process, under: row),
              layout: layout, theme: theme, metrics: metrics)
          }
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      Text(t("debug.column.tab")).frame(maxWidth: .infinity, alignment: .leading)
      Text(t("debug.column.worktree")).frame(maxWidth: .infinity, alignment: .leading)
      Text(t("debug.column.processes")).debugColumnTitle(width: metrics.debugCountColumnWidth)
      Text(t("debug.column.self")).debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      Text(t("debug.column.total-memory"))
        .debugColumnTitle(width: metrics.debugMemoryBarColumnWidth)
    }
    .debugTableHeader(theme, metrics, leadingInset: UIMetrics.debugTableTitleInset)
  }

  private func toggleExpansion(of source: DebugMemoryRow.Source) {
    if expandedSources.remove(source) == nil { expandedSources.insert(source) }
  }
}
