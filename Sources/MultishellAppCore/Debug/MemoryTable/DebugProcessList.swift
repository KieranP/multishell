import MultishellProcess

/// Processes shown under one row of the Memory by tab table, their trees laid
/// out once rather than at every read.
struct DebugProcessList: Sendable, Equatable {
  let processes: [ProcessUsage]
  let rows: [DebugProcessRow]
  /// What the tops of its trees hold themselves: a tab's panes' shells.
  let selfMemory: UInt64
  let totalMemory: UInt64

  init(processes: [ProcessUsage]) {
    self.processes = processes
    rows = DebugProcessRow.rows(of: processes)
    selfMemory = rows.topLevelMemory
    totalMemory = processes.totalMemory
  }
}
