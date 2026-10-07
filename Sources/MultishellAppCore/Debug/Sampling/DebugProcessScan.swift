import MultishellCore
import MultishellProcess

/// One look at the app and everything under it, each pane's terminal path
/// turned into the device number the trees name. Taken off the main actor.
struct DebugProcessScan: Sendable {
  let app: ProcessUsage?
  let trees: [ProcessTree]
  let terminalDevices: [TerminalSession.ID: Int32]

  static func take(
    appPID: Int32, terminalPaths: [TerminalSession.ID: String]
  ) -> DebugProcessScan {
    DebugProcessScan(
      app: ProcessTreeScan.usage(of: appPID), trees: ProcessTreeScan.childTrees(of: appPID),
      terminalDevices: terminalPaths.compactMapValues(TerminalDevice.number(atPath:)))
  }

  var childProcesses: [ProcessUsage] { trees.flatMap(\.processes) }
}
