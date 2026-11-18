import MultishellCore
import MultishellProcess

/// The Memory Breakdown table: the app itself, opening into its parts, each tab
/// with a live shell, and what the app started that no tab runs.
public struct DebugMemoryTable: Sendable, Equatable {
  /// The app's whole footprint, its tabs' terminals included.
  let appMemory: UInt64
  /// Heaviest first.
  let tabs: [DebugTabMemory]
  let unattributed: DebugProcessList
  let fileTabs: DebugFileTabMemory
  /// `nil` where the kernel would not describe the app, or a test gave none.
  let appParts: ProcessMemoryParts?
  /// The footprint and every child, as measured; the rows' own sum can
  /// exceed it where a terminal's estimate reads more than it occupies.
  let totalMemory: UInt64

  /// The footprint less what the tabs' terminals hold, which their rows show.
  /// Never below zero: Ghostty counts a page at its full allocated size.
  var appMemoryOutsideTerminals: UInt64 {
    appMemory.subtractingFlooredAtZero(tabs.reduce(0) { $0 + ($1.terminalMemory ?? 0) })
  }

  /// The app's row split by what holds it, each part capped at what the parts
  /// before it left, so they add up to the row. The file tabs' text is heap in use.
  var appPartRows: [DebugAppPartRow] {
    let appRowMemory = appMemoryOutsideTerminals
    guard let appParts else {
      guard fileTabs.tabCount > 0 else { return [] }
      return [fileTabsRow(memory: min(fileTabs.contentMemory, appRowMemory), indentLevel: 0)]
    }
    let gpu = min(appParts.gpuMemory, appRowMemory)
    let heap = min(appParts.heapMemory, appRowMemory - gpu)
    let heapInUse = min(appParts.heapInUse, heap)
    let fileTabText = min(fileTabs.contentMemory, heapInUse)
    var rows = [
      DebugAppPartRow(part: .gpu, selfMemory: gpu),
      DebugAppPartRow(
        part: .heapInUse,
        selfMemory: heapInUse - fileTabText,
        totalMemory: heapInUse,
      ),
    ]
    if fileTabs.tabCount > 0 { rows.append(fileTabsRow(memory: fileTabText, indentLevel: 1)) }
    rows.append(DebugAppPartRow(part: .freedHeap, selfMemory: heap - heapInUse))
    rows.append(
      DebugAppPartRow(part: .librariesAndOther, selfMemory: appRowMemory - gpu - heap)
    )
    return rows
  }

  /// The app, the tabs and Other processes where there are any, and the total,
  /// each bar against the heaviest row.
  var rows: [DebugMemoryRow] {
    let appRowMemory = appMemoryOutsideTerminals
    let heaviest = Double(
      max(
        appRowMemory,
        unattributed.totalMemory,
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
        appPartRows: appPartRows,
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
          appPartRows: [],
          processRows: tab.processList.rows,
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
          appPartRows: [],
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
        appPartRows: [],
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
    appParts: ProcessMemoryParts? = nil,
  ) {
    self.appMemory = appMemory
    self.tabs = tabs
    self.fileTabs = fileTabs
    self.appParts = appParts
    unattributed = DebugProcessList(processes: unattributedProcesses)
    totalMemory = tabs.reduce(appMemory + unattributed.totalMemory) { total, tab in
      total + tab.processList.totalMemory
    }
  }

  /// The rows in the order the table's header picked, the total last whatever it is.
  public func rows(sortedBy sort: DebugTableSort<DebugMemoryColumn>) -> [DebugMemoryRow] {
    let rows = rows
    return sort.ordered(rows.filter { !$0.isTotal }) + rows.filter(\.isTotal)
  }

  private func fileTabsRow(memory: UInt64, indentLevel: Int) -> DebugAppPartRow {
    DebugAppPartRow(
      part: .fileTabs,
      selfMemory: memory,
      indentLevel: indentLevel,
      fileTabCount: fileTabs.tabCount,
    )
  }
}
