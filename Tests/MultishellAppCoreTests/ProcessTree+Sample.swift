@testable import MultishellProcess

extension ProcessTree {
  /// A root and the pids under it, the root's own among them where listed.
  static func sample(root: Int32, device: Int32? = nil, pids: [Int32]) -> ProcessTree {
    ProcessTree(
      rootPID: root, terminalDevice: device, processes: pids.map { ProcessUsage.sample(pid: $0) })
  }
}
