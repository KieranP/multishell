import MultishellCore
import MultishellProcess

/// Which of the app's child trees each pane runs: the tree on its terminal,
/// else the one holding its foreground process. A tree goes to one pane.
struct PaneProcessAttribution: Sendable, Equatable {
  let processesBySession: [TerminalSession.ID: [ProcessUsage]]
  /// A git or hook the app started, or a pane the engine could not place.
  let unattributedProcesses: [ProcessUsage]

  static let empty = PaneProcessAttribution(
    trees: [], terminalDevices: [:], foregroundPIDs: [:])

  init(
    trees: [ProcessTree], terminalDevices: [TerminalSession.ID: Int32],
    foregroundPIDs: [TerminalSession.ID: Int32]
  ) {
    var unclaimed = trees
    var bySession: [TerminalSession.ID: [ProcessUsage]] = [:]
    let sessions = Set(terminalDevices.keys).union(foregroundPIDs.keys)
    for session in sessions.sorted(by: { $0.uuidString < $1.uuidString }) {
      let index =
        terminalDevices[session].flatMap { device in
          unclaimed.firstIndex { $0.terminalDevice == device }
        }
        ?? foregroundPIDs[session].flatMap { pid in unclaimed.firstIndex { $0.contains(pid) } }
      guard let index else { continue }
      bySession[session] = unclaimed.remove(at: index).processes
    }
    processesBySession = bySession
    unattributedProcesses = unclaimed.flatMap(\.processes)
  }
}
