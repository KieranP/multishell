@testable import MultishellProcess

extension ProcessTree {
  /// A root and the pids under it, the root's own among them where listed.
  static func sample(root: Int32, pids: [Int32], device: Int32? = nil) -> ProcessTree {
    ProcessTree(
      rootPID: root,
      terminalDevice: device,
      processes: pids.map { ProcessUsage.sample(pid: $0) },
    )
  }
}
