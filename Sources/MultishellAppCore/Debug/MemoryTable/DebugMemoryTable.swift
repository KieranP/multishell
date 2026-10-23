import MultishellCore
import MultishellProcess

/// The Memory by tab table: the app itself, each tab with a live shell, the
/// file tabs' text, and what the app started that no tab runs.
public struct DebugMemoryTable: Sendable, Equatable {
  /// The app's whole footprint, its tabs' terminals included.
  let appMemory: UInt64
  /// Heaviest first.
  let tabs: [DebugTabMemory]
  let unattributed: DebugProcessList
  let fileTabs: DebugFileTabMemory
  /// The footprint and every child, as measured; the rows' own sum can
  /// exceed it where a terminal's estimate reads more than it occupies.
  let totalMemory: UInt64

  /// The footprint less what the tabs' terminals and the file tabs' text
  /// hold, which their rows show. Never below zero: both are estimates.
  var appMemoryOutsideTabs: UInt64 {
    appMemory.subtractingFlooredAtZero(
      tabs.reduce(fileTabs.textMemory) { $0 + ($1.terminalMemory ?? 0) }
    )
  }

  /// The app, the tabs, file tabs and Other processes where there are any, and the total,
  /// each bar against the heaviest row.
  public var rows: [DebugMemoryRow] {
    let appRowMemory = appMemoryOutsideTabs
    let heaviest = Double(
      max(
        appRowMemory,
        unattributed.totalMemory,
        fileTabs.textMemory,
        tabs.compactMap(\.totalMemory).max() ?? 0,
        1,
      )
    )
    let fraction = { (memory: UInt64?) in Double(memory ?? 0) / heaviest }
    var rows = [
      DebugMemoryRow(
        source: .app,
        title: t("debug.app-row"),
        subtitle: "",
        processCount: 1,
        selfMemory: appRowMemory,
        totalMemory: appRowMemory,
        barFraction: fraction(appRowMemory),
        terminalRow: nil,
        processRows: [],
      )
    ]
    for tab in tabs {
      rows.append(
        DebugMemoryRow(
          source: .tab(tab.id),
          title: tab.title,
          subtitle: tab.location.title,
          processCount: tab.processCount,
          selfMemory: tab.selfMemory,
          totalMemory: tab.totalMemory,
          barFraction: fraction(tab.totalMemory),
          terminalRow: tab.terminalRow,
          processRows: tab.processList.rows,
        )
      )
    }
    if fileTabs.tabCount > 0 {
      rows.append(
        DebugMemoryRow(
          source: .fileTabs,
          title: t("debug.file-tabs-row"),
          subtitle: t("debug.file-tabs-row-subtitle", fileTabs.tabCount),
          processCount: nil,
          selfMemory: fileTabs.textMemory,
          totalMemory: fileTabs.textMemory,
          barFraction: fraction(fileTabs.textMemory),
          terminalRow: nil,
          processRows: [],
        )
      )
    }
    if !unattributed.processes.isEmpty {
      rows.append(
        DebugMemoryRow(
          source: .unattributed,
          title: t("debug.other-row"),
          subtitle: t("debug.other-row-subtitle"),
          processCount: unattributed.processes.count,
          selfMemory: unattributed.selfMemory,
          totalMemory: unattributed.totalMemory,
          barFraction: fraction(unattributed.totalMemory),
          terminalRow: nil,
          processRows: unattributed.rows,
        )
      )
    }
    rows.append(
      DebugMemoryRow(
        source: .total,
        title: t("debug.total-row"),
        subtitle: "",
        processCount: nil,
        selfMemory: nil,
        totalMemory: totalMemory,
        barFraction: 0,
        terminalRow: nil,
        processRows: [],
      )
    )
    return rows
  }

  init(
    appMemory: UInt64,
    tabs: [DebugTabMemory],
    unattributedProcesses: [ProcessUsage],
    fileTabs: DebugFileTabMemory = .noTabs,
  ) {
    self.appMemory = appMemory
    self.tabs = tabs
    self.fileTabs = fileTabs
    unattributed = DebugProcessList(processes: unattributedProcesses)
    totalMemory = tabs.reduce(appMemory + unattributed.totalMemory) { total, tab in
      total + tab.processList.totalMemory
    }
  }
}
