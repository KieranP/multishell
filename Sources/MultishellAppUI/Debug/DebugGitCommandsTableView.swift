import MultishellAppCore
import MultishellCore
import SwiftUI

/// Every git command run over the range, the most time spent first.
struct DebugGitCommandsTableView: View {
  let gitCommands: [DebugGitCommand]
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    VStack(spacing: 0) {
      if gitCommands.isEmpty {
        Text(t("debug.no-git"))
          .font(.system(size: metrics.secondary))
          .foregroundStyle(theme.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .debugTableRow(theme, verticalPadding: 6)
      } else {
        if layout == .columns { header }
        ForEach(gitCommands) { gitCommand in
          DebugGitCommandRow(
            gitCommand: gitCommand, layout: layout, theme: theme, metrics: metrics)
        }
      }
    }
  }

  private var header: some View {
    HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      Text(t("debug.column.command")).frame(maxWidth: .infinity, alignment: .leading)
      Text(t("debug.column.runs")).debugColumnTitle(width: metrics.debugCountColumnWidth)
      Text(t("debug.column.total")).debugColumnTitle(width: metrics.debugDurationColumnWidth)
      Text(t("debug.column.mean")).debugColumnTitle(width: metrics.debugDurationColumnWidth)
      Text(t("debug.column.slowest")).debugColumnTitle(width: metrics.debugDurationColumnWidth)
      Text(t("debug.column.mean-memory"))
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      Text(t("debug.column.peak-memory"))
        .debugColumnTitle(width: metrics.debugMemoryValueColumnWidth)
      Text(t("debug.column.slowest-in")).frame(maxWidth: .infinity, alignment: .leading)
    }
    .debugTableHeader(theme, metrics)
  }
}
