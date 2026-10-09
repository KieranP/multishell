@testable import MultishellProcess

extension ProcessUsage {
  static func sample(
    pid: Int32,
    parentPID: Int32 = 1,
    footprint: UInt64 = 100,
    cpuTime: Duration = .zero,
  ) -> ProcessUsage {
    ProcessUsage(
      pid: pid,
      parentPID: parentPID,
      name: "p\(pid)",
      footprint: footprint,
      cpuTime: cpuTime,
    )
  }
}
