import MultishellCore
import MultishellProcess

/// The Memory by tab table: the app itself, each tab with a live shell, and
/// what the app started that no tab runs.
public struct DebugMemoryTable: Sendable, Equatable {
  let appMemory: UInt64
  /// Heaviest first.
  let tabs: [DebugTabMemory]
  let unattributed: DebugProcessList
  let totalMemory: UInt64

  init(appMemory: UInt64, tabs: [DebugTabMemory], unattributedProcesses: [ProcessUsage]) {
    self.appMemory = appMemory
    self.tabs = tabs
    unattributed = DebugProcessList(processes: unattributedProcesses)
    totalMemory = tabs.reduce(appMemory + unattributed.totalMemory) {
      $0 + $1.processList.totalMemory
    }
  }

  /// The app, the tabs, Other processes where there are any, and the total,
  /// each bar against the heaviest row.
  public var rows: [DebugMemoryRow] {
    let heaviest = Double(
      max(appMemory, unattributed.totalMemory, tabs.first?.processList.totalMemory ?? 0, 1))
    let fraction = { (memory: UInt64?) in Double(memory ?? 0) / heaviest }
    var rows = [
      DebugMemoryRow(
        source: .app, title: t("debug.app-row"), subtitle: t("debug.app-row-subtitle"),
        processCount: 1, selfMemory: appMemory, totalMemory: appMemory,
        barFraction: fraction(appMemory), processRows: [])
    ]
    for tab in tabs {
      let placedList = tab.isPlaced ? tab.processList : nil
      rows.append(
        DebugMemoryRow(
          source: .tab(tab.id), title: tab.title, subtitle: tab.location.title,
          processCount: placedList?.processes.count, selfMemory: placedList?.selfMemory,
          totalMemory: placedList?.totalMemory, barFraction: fraction(placedList?.totalMemory),
          processRows: tab.processList.rows))
    }
    if !unattributed.processes.isEmpty {
      rows.append(
        DebugMemoryRow(
          source: .unattributed, title: t("debug.other-row"),
          subtitle: t("debug.other-row-subtitle"), processCount: unattributed.processes.count,
          selfMemory: unattributed.selfMemory, totalMemory: unattributed.totalMemory,
          barFraction: fraction(unattributed.totalMemory), processRows: unattributed.rows))
    }
    rows.append(
      DebugMemoryRow(
        source: .total, title: t("debug.total-row"), subtitle: "", processCount: nil,
        selfMemory: nil, totalMemory: totalMemory, barFraction: 0, processRows: []))
    return rows
  }
}
