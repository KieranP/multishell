import MultishellCore

extension AppModel {
  /// Each tab with a live shell, from what its panes were last seen running
  /// and what their terminals held.
  public var debugMemoryTable: DebugMemoryTable {
    let snapshot = shownDebugSnapshot
    let processesBySession = snapshot.attribution.processesBySession
    let terminalMemoryBySession = snapshot.terminalMemoryBySession
    let worktreesByID = workspace.worktrees.keyedByID()
    let tabs = workspace.tabs.compactMap { tab -> DebugTabMemory? in
      let liveSessions = tab.sessionIDs.filter(liveSessionIDs.contains)
      guard !liveSessions.isEmpty, let worktree = worktreesByID[tab.worktreeID] else { return nil }
      let terminalReadings = liveSessions.compactMap { terminalMemoryBySession[$0] }
      return DebugTabMemory(
        id: tab.id,
        title: title(of: tab),
        location: debugLocation(of: worktree),
        terminalMemory: terminalReadings.isEmpty ? nil : terminalReadings.reduce(0, +),
        processes: liveSessions.flatMap { processesBySession[$0] ?? [] }.heaviestFirst(),
      )
    }
    return DebugMemoryTable(
      appMemory: snapshot.history.latest?.appMemory ?? 0,
      tabs: tabs.sorted { lhs, rhs in
        (lhs.totalMemory ?? 0, rhs.title) > (rhs.totalMemory ?? 0, lhs.title)
      },
      unattributedProcesses: snapshot.attribution.unattributedProcesses.heaviestFirst(),
      fileTabs: debugFileTabMemory,
    )
  }

  /// UTF-16 kept for each line, twice over for the rows' joined text: the
  /// model's copy, not the layout a shown tab adds on top.
  private var debugFileTabMemory: DebugFileTabMemory {
    let bytes = fileTabReadings.values.reduce(UInt64(0)) { total, reading in
      guard case .text(let rows) = reading.content else { return total }
      return total + UInt64(rows.displayText.string.utf16.count) * 4
    }
    return DebugFileTabMemory(tabCount: workspace.fileTabs.count, textMemory: bytes)
  }
}
