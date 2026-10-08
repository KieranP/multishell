import MultishellAppCore
import MultishellCore
import SwiftUI

/// A row of the Git commands table: in columns, or with its numbers stacked
/// under the command where the panel is too narrow for them.
struct DebugGitCommandRow: View {
  let gitCommand: DebugGitCommand
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  var body: some View {
    Group {
      switch layout {
      case .columns: columns
      case .stacked:
        DebugStackedRow(
          captions: gitCommand.stackedCaptions, theme: theme, metrics: metrics
        ) {
          command
        } headline: {
          Text(gitCommand.totalDurationText)
            .monospacedDigit()
            .foregroundStyle(theme.textPrimary)
        }
      }
    }
    .font(.system(size: metrics.secondary))
    .fixedSize(horizontal: false, vertical: true)
    .debugTableRow(theme)
    .debugTableRowHighlight(theme)
  }

  private var columns: some View {
    HStack(alignment: .firstTextBaseline, spacing: UIMetrics.debugTableColumnSpacing) {
      command.frame(maxWidth: .infinity, alignment: .leading)
      number(gitCommand.runCountText, width: metrics.debugCountColumnWidth)
      number(gitCommand.totalDurationText)
      number(gitCommand.meanDurationText)
      number(gitCommand.slowestDurationText)
      number(gitCommand.meanPeakMemoryText, width: metrics.debugMemoryValueColumnWidth)
      number(gitCommand.peakMemoryText, width: metrics.debugMemoryValueColumnWidth)
      Text(gitCommand.slowestLocationText)
        .foregroundStyle(theme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
  }

  private var command: some View {
    Text(gitCommand.command)
      .font(.system(size: metrics.caption, design: .monospaced))
      .foregroundStyle(theme.textPrimary)
  }

  private func number(_ text: String, width: Double? = nil) -> some View {
    DebugNumberCell(
      text: text, width: width ?? metrics.debugDurationColumnWidth, color: theme.textPrimary)
  }
}
