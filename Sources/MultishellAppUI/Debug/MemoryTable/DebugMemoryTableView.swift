import MultishellAppCore
import MultishellCore
import MultishellProcess
import SwiftUI

/// The app, each tab and what no tab runs, in the order the headers pick,
/// then the total. The app expands to its parts, a row with processes to list them.
struct DebugMemoryTableView: View {
  let table: DebugMemoryTable
  @Binding var sort: DebugTableSort<DebugMemoryColumn>
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  @State private var expandedSources: Set<DebugMemoryRow.Source> = []

  var body: some View {
    VStack(spacing: 0) {
      if layout == .columns { header }
      ForEach(table.rows(sortedBy: sort)) { row in
        let disclosure = row.disclosure(isExpanded: expandedSources.contains(row.source))
        DebugMemoryRowView(
          row: row,
          disclosure: disclosure,
          toggleExpansion: { toggleExpansion(of: row.source) },
          layout: layout,
          theme: theme,
          metrics: metrics,
        )
        if disclosure == .expanded {
          if let terminal = row.terminalRow {
            DebugNestedRowView(
              name: terminal.title,
              namesAProcess: false,
              indentLevel: 0,
              memory: terminal,
              accessibilityLabel: AccessibilityText.debugTerminalRow(terminal),
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
          ForEach(row.appPartRows) { part in
            DebugNestedRowView(
              name: part.title,
              namesAProcess: false,
              indentLevel: part.indentLevel,
              memory: part,
              accessibilityLabel: AccessibilityText.debugAppPartRow(part),
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
          ForEach(row.processRows) { process in
            DebugNestedRowView(
              name: process.process.name,
              namesAProcess: true,
              indentLevel: row.indentLevel(of: process),
              memory: process,
              accessibilityLabel: AccessibilityText.debugProcessRow(process, under: row),
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
        }
      }
    }
  }

  private var header: some View {
    let headers = DebugColumnHeaders(sort: $sort, theme: theme, metrics: metrics)
    return HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      headers.button(t("debug.column.tab"), .name).frame(maxWidth: .infinity, alignment: .leading)
      headers.button(t("debug.column.worktree"), .worktree)
        .frame(maxWidth: .infinity, alignment: .leading)
      headers.button(t("debug.column.processes"), .processCount)
        .debugColumnTitle(width: metrics.debugCountColumnWidth)
      headers.button(t("debug.column.self"), .selfMemory)
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      Color.clear.frame(width: metrics.debugMemoryBarColumnWidth, height: 1)
      headers.button(t("debug.column.total-memory"), .totalMemory)
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
    }
    .debugTableHeader(theme, metrics, leadingInset: UIMetrics.debugTableTitleInset)
  }

  private func toggleExpansion(of source: DebugMemoryRow.Source) {
    if expandedSources.remove(source) == nil { expandedSources.insert(source) }
  }
}
