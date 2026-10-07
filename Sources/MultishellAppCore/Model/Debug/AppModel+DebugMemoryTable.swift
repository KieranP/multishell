import MultishellCore

extension AppModel {
  /// Each tab with a live shell, from what its panes were last seen running.
  public var debugMemoryTable: DebugMemoryTable {
    let snapshot = shownDebugSnapshot
    let processesBySession = snapshot.attribution.processesBySession
    let worktreesByID = workspace.worktrees.keyedByID()
    let tabs = workspace.tabs.compactMap { tab -> DebugTabMemory? in
      let liveSessions = tab.sessionIDs.filter(liveSessionIDs.contains)
      guard !liveSessions.isEmpty, let worktree = worktreesByID[tab.worktreeID] else { return nil }
      return DebugTabMemory(
        id: tab.id, title: title(of: tab), location: debugLocation(of: worktree),
        processes: liveSessions.flatMap { processesBySession[$0] ?? [] }.heaviestFirst())
    }
    return DebugMemoryTable(
      appMemory: snapshot.history.latest?.appMemory ?? 0,
      tabs: tabs.sorted {
        ($0.processList.totalMemory, $1.title) > ($1.processList.totalMemory, $0.title)
      },
      unattributedProcesses: snapshot.attribution.unattributedProcesses.heaviestFirst())
  }
}
