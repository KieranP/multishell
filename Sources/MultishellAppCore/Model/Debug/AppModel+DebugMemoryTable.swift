import MultishellCore

extension AppModel {
  /// Each tab with a live shell, from what its panes were last seen running
  /// and what their terminals held.
  public var debugMemoryTable: DebugMemoryTable { pausedDebugMemoryTable ?? liveDebugMemoryTable }

  /// The command line's table, read on while the panel is paused.
  var liveDebugMemoryTable: DebugMemoryTable { debugMemoryTable(of: liveDebugSnapshot) }

  /// The model's copy, not a shown tab's layout or picture: UTF-16 per line, twice
  /// for joined text, and image bytes. All changes tabs count with the file tabs.
  private var debugFileTabMemory: DebugFileTabMemory {
    let bytes = fileTabReadings.values.reduce(UInt64(0)) { total, reading in
      switch reading.content {
      case .image(let image):
        return total + UInt64(image.shownCopies.reduce(0) { $0 + $1.image.data.count })

      case .text(let rows):
        return total + UInt64(rows.displayText.string.utf16.count) * 4

      case .binary, .missing, .released, .releasedFollowingStatus, .tooLarge, .unreadable:
        return total
      }
    }
    return DebugFileTabMemory(
      tabCount: workspace.fileTabs.count + workspace.allChangesTabs.count,
      contentMemory: bytes + debugAllChangesMemory,
    )
  }

  private var debugAllChangesMemory: UInt64 {
    let rows = allChangesReadings.values.reduce(UInt64(0)) { total, reading in
      reading.files.reduce(total) { total, file in
        total + UInt64(file.rows?.displayText.string.utf16.count ?? 0) * 4
      }
    }
    let documents = allChangesDocuments.values.reduce(UInt64(0)) { total, entry in
      let document = entry.document
      let units =
        document.text.string.utf16.count + (document.committedText?.string.utf16.count ?? 0)
      return total + UInt64(units) * 4
    }
    return rows + documents
  }

  private func debugMemoryTable(of snapshot: DebugSnapshot) -> DebugMemoryTable {
    let processesBySession = snapshot.attribution.processesBySession
    let terminalMemoryBySession = snapshot.terminalMemoryBySession
    let worktreesByID = workspace.worktrees.keyedByID()
    let tabs = workspace.tabs.compactMap { tab -> DebugTabMemory? in
      let liveSessions = tab.sessionIDs.filter(liveSessionIDs.contains)
      guard !liveSessions.isEmpty, let worktree = worktreesByID[tab.worktreeID] else { return nil }
      let terminalReadings = liveSessions.compactMap { terminalMemoryBySession[$0] }
      return DebugTabMemory(
        id: tab.id,
        title: shownTitle(of: tab),
        location: debugLocation(of: worktree),
        terminalMemory: terminalReadings.isEmpty ? nil : terminalReadings.reduce(0, +),
        processes: liveSessions.flatMap { processesBySession[$0] ?? [] }.heaviestFirst(),
      )
    }
    // A pane closed since the sample has no row; its processes stay in the measured total.
    let shownSessions = Set(workspace.tabs.flatMap(\.sessionIDs).filter(liveSessionIDs.contains))
    let ofClosedPanes = processesBySession.filter { !shownSessions.contains($0.key) }.values
    return DebugMemoryTable(
      appMemory: snapshot.history.latest?.appMemory ?? 0,
      tabs: tabs.sorted { lhs, rhs in
        (lhs.totalMemory ?? 0, rhs.title) > (rhs.totalMemory ?? 0, lhs.title)
      },
      unattributedProcesses: (snapshot.attribution.unattributedProcesses + ofClosedPanes.joined())
        .heaviestFirst(),
      fileTabs: debugFileTabMemory,
      appParts: snapshot.appMemoryParts,
    )
  }
}
