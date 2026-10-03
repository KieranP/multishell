import MultishellCore
import MultishellProcess

/// The Memory by tab table: the app itself, each tab with a live shell, and
/// what the app started that no tab runs.
public struct DebugMemoryTable: Sendable, Equatable {
  let appMemory: UInt64
  /// Heaviest first.
  let tabs: [DebugTabMemory]
  let unattributed: DebugProcessGroup
  let totalMemory: UInt64

  init(appMemory: UInt64, tabs: [DebugTabMemory], unattributedProcesses: [ProcessUsage]) {
    self.appMemory = appMemory
    self.tabs = tabs
    unattributed = DebugProcessGroup(processes: unattributedProcesses)
    totalMemory = tabs.reduce(appMemory + unattributed.totalMemory) { $0 + $1.group.totalMemory }
  }

  /// The app, the tabs, Other processes where there are any, and the total,
  /// each bar against the heaviest row.
  public var lines: [DebugMemoryLine] {
    let heaviest = Double(
      max(appMemory, unattributed.totalMemory, tabs.first?.group.totalMemory ?? 0, 1))
    let fraction = { (memory: UInt64?) in Double(memory ?? 0) / heaviest }
    var lines = [
      DebugMemoryLine(
        source: .app, title: t("debug.app-row"), subtitle: t("debug.app-row-subtitle"),
        processCount: 1, selfMemory: appMemory, totalMemory: appMemory,
        barFraction: fraction(appMemory), processLines: [])
    ]
    for tab in tabs {
      let group = tab.isPlaced ? tab.group : nil
      lines.append(
        DebugMemoryLine(
          source: .tab(tab.id), title: tab.title, subtitle: tab.location.title,
          processCount: group?.processes.count, selfMemory: group?.selfMemory,
          totalMemory: group?.totalMemory, barFraction: fraction(group?.totalMemory),
          processLines: tab.group.lines))
    }
    if !unattributed.processes.isEmpty {
      lines.append(
        DebugMemoryLine(
          source: .unattributed, title: t("debug.other-row"),
          subtitle: t("debug.other-row-subtitle"), processCount: unattributed.processes.count,
          selfMemory: unattributed.selfMemory, totalMemory: unattributed.totalMemory,
          barFraction: fraction(unattributed.totalMemory), processLines: unattributed.lines))
    }
    lines.append(
      DebugMemoryLine(
        source: .total, title: t("debug.total-row"), subtitle: "", processCount: nil,
        selfMemory: nil, totalMemory: totalMemory, barFraction: 0, processLines: []))
    return lines
  }
}
