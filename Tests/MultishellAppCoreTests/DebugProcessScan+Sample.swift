import MultishellCore

@testable import MultishellAppCore
@testable import MultishellProcess

extension DebugProcessScan {
  /// The app at `appMemory`, and one child tree per entry, each a root and
  /// the pids under it at a footprint of 100 apiece.
  static func sample(
    appMemory: UInt64,
    trees: [(root: Int32, pids: [Int32])],
    appParts: ProcessMemoryParts? = nil,
    appActivity: ProcessActivity? = nil,
    threads: [ThreadUsage] = [],
    openDescriptorCount: Int? = nil,
    memoryPressure: MemoryPressureLevel? = nil,
  ) -> DebugProcessScan {
    DebugProcessScan(
      app: ProcessUsage.sample(pid: 1, footprint: appMemory),
      appParts: appParts,
      appActivity: appActivity,
      threads: threads,
      openDescriptorCount: openDescriptorCount,
      memoryPressure: memoryPressure,
      trees: trees.map { ProcessTree.sample(root: $0.root, pids: $0.pids) },
      terminalDevices: [:],
    )
  }
}
