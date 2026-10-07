/// One child of the app and everything under it: a pane's `login` or shell
/// and what it runs, or a git or hook the app started.
public struct ProcessTree: Sendable, Equatable {
  let rootPID: Int32
  /// The root's controlling terminal, `nil` for a child with none.
  public let terminalDevice: Int32?
  /// Those readable, the root first where it is: a setuid `login` is not.
  public let processes: [ProcessUsage]

  public func contains(_ pid: Int32) -> Bool {
    rootPID == pid || processes.contains { $0.pid == pid }
  }
}
