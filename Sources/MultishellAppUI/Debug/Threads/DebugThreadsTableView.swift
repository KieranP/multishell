import MultishellAppCore
import MultishellCore
import SwiftUI

/// The app's threads over the range under their groups, each opening to list
/// its threads by name, both levels in the order the headers pick.
struct DebugThreadsTableView: View {
  let groups: [DebugThreadGroupRow]
  @Binding var sort: DebugTableSort<DebugThreadColumn>
  let layout: DebugTableLayout
  let theme: Theme
  let metrics: UIMetrics

  @State private var expandedGroups: Set<DebugThreadGroup> = []

  var body: some View {
    VStack(spacing: 0) {
      if groups.isEmpty {
        Text(t("debug.no-threads"))
          .font(metrics.font(size: metrics.secondary))
          .foregroundStyle(theme.debugInfo.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .debugTableRow(theme, verticalPadding: 6)
      } else {
        if layout == .columns { header }
        ForEach(groups) { group in
          let disclosure = group.disclosure(isExpanded: expandedGroups.contains(group.group))
          rowView(group, of: group.group, isNested: false, disclosure: disclosure)
          if disclosure == .expanded {
            ForEach(group.threads) { thread in
              rowView(thread, of: group.group, isNested: true, disclosure: .notExpandable)
            }
          }
        }
      }
    }
  }

  private var header: some View {
    let headers = DebugColumnHeaders(sort: $sort, theme: theme, metrics: metrics)
    return HStack(alignment: .bottom, spacing: UIMetrics.debugTableColumnSpacing) {
      headers.button(t("debug.column.thread"), .thread)
        .frame(maxWidth: .infinity, alignment: .leading)
      headers.button(t("debug.column.threads"), .threadCount)
        .debugColumnTitle(width: metrics.debugCountColumnWidth)
      headers.button(t("debug.column.mean-cpu"), .meanPercent)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
      headers.button(t("debug.column.total"), .cpuTime)
        .debugColumnTitle(width: metrics.debugDurationColumnWidth)
    }
    .debugTableHeader(theme, metrics, leadingInset: UIMetrics.debugTableTitleInset)
  }

  private func rowView(
    _ row: any DebugThreadFigures,
    of group: DebugThreadGroup,
    isNested: Bool,
    disclosure: DebugRowDisclosure,
  ) -> DebugThreadRowView {
    DebugThreadRowView(
      row: row,
      group: group,
      isNested: isNested,
      disclosure: disclosure,
      toggleExpansion: { toggleExpansion(of: group) },
      layout: layout,
      theme: theme,
      metrics: metrics,
    )
  }

  private func toggleExpansion(of group: DebugThreadGroup) {
    if expandedGroups.remove(group) == nil { expandedGroups.insert(group) }
  }
}
