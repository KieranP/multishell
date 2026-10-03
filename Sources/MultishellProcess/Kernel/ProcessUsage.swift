/// One running process, named, with what it holds and has spent.
public struct ProcessUsage: Sendable, Equatable {
  public let pid: Int32
  /// Which process started it, so a tree can be drawn from a flat list.
  public let parentPID: Int32
  public let name: String
  public let footprint: UInt64
  public let cpuTime: Duration

  init(pid: Int32, parentPID: Int32, name: String, footprint: UInt64, cpuTime: Duration) {
    self.pid = pid
    self.parentPID = parentPID
    self.name = name
    self.footprint = footprint
    self.cpuTime = cpuTime
  }
}
