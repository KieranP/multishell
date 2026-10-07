import MultishellAppCore
import MultishellCore
import SwiftUI

/// Debug Info: the strips over the range, then the two tables at their full
/// height, the panel scrolling as one. It decides nothing; the model does.
struct DebugInfoView: View {
  let model: AppModel
  let theme: Theme

  @State private var range = DebugRange.oneMinute

  var body: some View {
    let metrics = model.metrics
    let timeline = model.debugTimeline(for: range)
    VStack(spacing: 0) {
      DebugInfoHeader(
        model: model, timeline: timeline, range: $range, theme: theme,
        metrics: metrics)
      ScrollView(.vertical) {
        VStack(spacing: 14) {
          DebugTimelineView(timeline: timeline, theme: theme, metrics: metrics)
          DebugTableBlock(
            title: t("debug.memory-by-tab"), caption: t("debug.memory-by-tab-caption"),
            columnsWidthInEms: DebugTableLayout.memoryTableColumnsWidthInEms, theme: theme,
            metrics: metrics
          ) { layout in
            DebugMemoryTableView(
              table: model.debugMemoryTable, layout: layout, theme: theme, metrics: metrics)
          }
          DebugTableBlock(
            title: t("debug.git-commands"), caption: t("debug.git-commands-caption", range.title),
            columnsWidthInEms: DebugTableLayout.gitTableColumnsWidthInEms, theme: theme,
            metrics: metrics
          ) { layout in
            DebugGitCommandsTableView(
              gitCommands: model.debugGitCommands(for: range), layout: layout, theme: theme,
              metrics: metrics)
          }
        }
        .padding(14)
      }
    }
    .background(theme.backgroundColor)
  }
}
