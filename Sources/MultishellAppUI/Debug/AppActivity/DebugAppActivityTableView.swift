import MultishellAppCore
import MultishellCore
import SwiftUI

/// The app's own work over the range, timed where it ran, in the order its headers pick.
struct DebugAppActivityTableView: View {
  let rows: [DebugAppActivityRow]
  @Binding var sort: DebugTableSort<DebugAppActivityColumn>
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(spacing: 0) {
      if rows.isEmpty {
        Text(t("debug.no-app-activity"))
          .font(metrics.font(size: metrics.secondary))
          .foregroundStyle(theme.debugInfo.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .debugTableRow(theme, verticalPadding: 6)
      } else {
        if layout == .columns { header }
        ForEach(rows) { row in
          DebugAppActivityRowView(row: row, layout: layout, theme: theme, metrics: metrics)
        }
      }
    }
  }

  private var header: some View {
    let headers = DebugColumnHeaders(sort: $sort, theme: theme, metrics: metrics)
    return HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      headers.button(t("debug.column.activity"), .activity).frame(
        maxWidth: .infinity,
        alignment: .leading,
      )
      headers.button(t("debug.column.count"), .count)
        .debugColumnTitle(width: metrics.debugCountColumnWidth)
      headers.button(t("debug.column.total"), .totalDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.mean"), .meanDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.slowest"), .slowestDuration)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.written"), .bytesWritten)
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
    }
    .debugTableHeader(theme, metrics)
  }
}
