import MultishellAppCore
import MultishellCore
import SwiftUI

/// Debug Info: the tiles over the range, then the tables at their full
/// height, the panel scrolling as one. It decides nothing; the model does.
struct DebugInfoView: View {
  let model: AppModel
  let theme: Theme

  @State private var range = DebugRange.oneMinute
  @State private var threadSort = DebugThreadColumn.defaultSort
  @State private var memorySort = DebugMemoryColumn.defaultSort
  @State private var appActivitySort = DebugAppActivityColumn.defaultSort
  @State private var cliActivitySort = DebugCLIActivityColumn.defaultSort

  var body: some View {
    let metrics = model.metrics
    let timeline = model.debugTimeline(for: range)
    VStack(spacing: 0) {
      DebugInfoHeader(
        model: model,
        timeline: timeline,
        range: $range,
        theme: theme,
        metrics: metrics,
      )
      ScrollView(.vertical) {
        VStack(spacing: 14) {
          DebugTimelineView(timeline: timeline, theme: theme, metrics: metrics)
          DebugTableBlock(
            title: t("debug.cpu-breakdown"),
            caption: t("debug.cpu-breakdown-caption", range.title, threadSort.title),
            columnsWidthInEms: DebugTableLayout.threadTableColumnsWidthInEms,
            theme: theme,
            metrics: metrics,
          ) { layout in
            DebugThreadsTableView(
              groups: model.debugThreadGroups(for: range, sortedBy: threadSort),
              sort: $threadSort,
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
          DebugTableBlock(
            title: t("debug.memory-breakdown"),
            caption: t("debug.memory-breakdown-caption", memorySort.title),
            columnsWidthInEms: DebugTableLayout.memoryTableColumnsWidthInEms,
            theme: theme,
            metrics: metrics,
          ) { layout in
            DebugMemoryTableView(
              table: model.debugMemoryTable,
              sort: $memorySort,
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
          DebugTableBlock(
            title: t("debug.app-activity"),
            caption: t("debug.app-activity-caption", range.title, appActivitySort.title),
            columnsWidthInEms: DebugTableLayout.appActivityTableColumnsWidthInEms,
            theme: theme,
            metrics: metrics,
          ) { layout in
            DebugAppActivityTableView(
              rows: model.debugAppActivityRows(for: range, sortedBy: appActivitySort),
              sort: $appActivitySort,
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
          DebugTableBlock(
            title: t("debug.cli-activity"),
            caption: t("debug.cli-activity-caption", range.title, cliActivitySort.title),
            columnsWidthInEms: DebugTableLayout.cliActivityTableColumnsWidthInEms,
            theme: theme,
            metrics: metrics,
          ) { layout in
            DebugCLIActivityTableView(
              rows: model.debugCLIActivityRows(for: range, sortedBy: cliActivitySort),
              sort: $cliActivitySort,
              layout: layout,
              theme: theme,
              metrics: metrics,
            )
          }
        }
        .padding(14)
      }
    }
    .background(theme.debugInfo.background)
  }
}
