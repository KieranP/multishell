import MultishellCore
import MultishellProcess

/// One look at the app and everything under it, each pane's terminal path
/// turned into the device number the trees name. Taken off the main actor.
struct DebugProcessScan: Sendable {
  let app: ProcessUsage?
  /// This process's own, as the scan is only taken for the app it runs in;
  /// so are its threads.
  let appParts: ProcessMemoryParts?
  let appActivity: ProcessActivity?
  let threads: [ThreadUsage]
  let openDescriptorCount: Int?
  /// The system's, not the app's.
  let memoryPressure: MemoryPressureLevel?
  let trees: [ProcessTree]
  let terminalDevices: [TerminalSession.ID: Int32]

  var childProcesses: [ProcessUsage] { trees.flatMap(\.processes) }

  static func take(
    appPID: Int32,
    terminalPaths: [TerminalSession.ID: String],
    mainThreadID: UInt64,
  ) -> Self {
    Self(
      app: ProcessTreeScan.usage(of: appPID),
      appParts: ProcessMemoryParts.ofThisProcess(),
      appActivity: ProcessActivity.of(appPID),
      threads: ThreadUsage.ofThisProcess(mainThreadID: mainThreadID),
      openDescriptorCount: OpenDescriptorCount.of(appPID),
      memoryPressure: MemoryPressureLevel.current(),
      trees: ProcessTreeScan.childTrees(of: appPID),
      terminalDevices: terminalPaths.compactMapValues(TerminalDevice.number(atPath:)),
    )
  }
}
