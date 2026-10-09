import MultishellCore
import MultishellProcess

/// A tab's row in the Memory by tab table: its panes' terminals and every
/// process they run, heaviest first, or none where the engine cannot place them.
struct DebugTabMemory: Sendable, Equatable, Identifiable {
  let id: TerminalTab.ID
  let title: String
  let location: DebugLocation
  /// Its panes' screens and scrollback, held in the app's own process;
  /// `nil` where the engine reported none.
  let terminalMemory: UInt64?
  let processList: DebugProcessList

  init(
    id: TerminalTab.ID, title: String, location: DebugLocation, terminalMemory: UInt64?,
    processes: [ProcessUsage]
  ) {
    self.id = id
    self.title = title
    self.location = location
    self.terminalMemory = terminalMemory
    processList = DebugProcessList(processes: processes)
  }

  /// A tab with a live shell always runs one, so none found means the engine
  /// could not place it, and its processes are unknown rather than none.
  var isPlaced: Bool { !processList.processes.isEmpty }

  var processCount: Int? { isPlaced ? processList.processes.count : nil }

  /// Its terminals and its shells. An unplaced tab's processes sit under
  /// Other processes, so its terminal alone keeps the rows adding up.
  var selfMemory: UInt64? {
    isPlaced ? (terminalMemory ?? 0) + processList.selfMemory : terminalMemory
  }

  /// Its terminals and every process, or the terminal alone while unplaced;
  /// `nil` where neither is known.
  var totalMemory: UInt64? {
    isPlaced ? (terminalMemory ?? 0) + processList.totalMemory : terminalMemory
  }

  /// The nested row heading it when open, whose Total takes in the shells under it.
  var terminalRow: DebugTerminalRow? {
    terminalMemory.map { DebugTerminalRow(selfMemory: $0, totalMemory: totalMemory ?? $0) }
  }
}
