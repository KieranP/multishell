import MultishellAppCore
import MultishellCore
import SwiftUI

/// Every command the CLIs ran over the range, in the order its headers pick.
struct DebugCLIActivityTableView: View {
  let rows: [DebugCLIActivityRow]
  @Binding var sort: DebugTableSort<DebugCLIActivityColumn>
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(spacing: 0) {
      if rows.isEmpty {
        Text(t("debug.no-cli-activity"))
          .font(metrics.font(size: metrics.secondary))
          .foregroundStyle(theme.debugInfo.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .debugTableRow(theme, verticalPadding: 6)
      } else {
        if layout == .columns { header }
        ForEach(rows) { row in
          DebugCLIActivityRowView(
            row: row,
            layout: layout,
            theme: theme,
            metrics: metrics,
          )
        }
      }
    }
  }

  private var header: some View {
    let headers = DebugColumnHeaders(sort: $sort, theme: theme, metrics: metrics)
    return HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      headers.button(t("debug.column.command"), .command)
        .frame(maxWidth: .infinity, alignment: .leading)
      headers.button(t("debug.column.runs"), .runs)
        .debugColumnTitle(width: metrics.debugCountColumnWidth)
      headers.button(t("debug.column.total"), .totalDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.mean"), .meanDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.slowest"), .slowestDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.mean-memory"), .meanPeakMemory)
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      headers.button(t("debug.column.peak-memory"), .peakMemory)
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      headers.button(t("debug.column.slowest-in"), .slowestLocation)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .debugTableHeader(theme, metrics)
  }
}
