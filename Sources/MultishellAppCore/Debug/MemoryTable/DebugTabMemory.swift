import MultishellCore
import MultishellProcess

/// A tab's row in the Memory by tab table: every process its panes run,
/// heaviest first. None where the engine could not say which were its.
struct DebugTabMemory: Sendable, Equatable, Identifiable {
  let id: TerminalTab.ID
  let title: String
  let location: DebugLocation
  let processList: DebugProcessList

  init(id: TerminalTab.ID, title: String, location: DebugLocation, processes: [ProcessUsage]) {
    self.id = id
    self.title = title
    self.location = location
    processList = DebugProcessList(processes: processes)
  }

  /// A tab with a live shell always runs one, so none found means the engine
  /// could not place it, and its memory is unknown rather than zero.
  var isPlaced: Bool { !processList.processes.isEmpty }
}
