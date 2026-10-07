import MultishellAppCore
import MultishellCore
import SwiftUI

/// The app, each tab heaviest first, what no tab runs, and the total. A row
/// with processes expands to list them.
struct DebugMemoryTableView: View {
  let table: DebugMemoryTable
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  @State private var expandedSources: Set<DebugMemoryLine.Source> = []

  var body: some View {
    VStack(spacing: 0) {
      if layout == .columns { header }
      ForEach(table.lines) { line in
        let disclosure = line.disclosure(isExpanded: expandedSources.contains(line.source))
        DebugMemoryRow(
          line: line, disclosure: disclosure, toggleExpansion: { toggleExpansion(of: line.source) },
          layout: layout, theme: theme, metrics: metrics)
        if disclosure == .expanded {
          ForEach(line.processLines) { process in
            DebugProcessRow(line: process, layout: layout, theme: theme, metrics: metrics)
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

  private func toggleExpansion(of source: DebugMemoryLine.Source) {
    if expandedSources.remove(source) == nil { expandedSources.insert(source) }
  }
}
