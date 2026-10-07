/// One running process, named, with what it holds and has spent.
public struct ProcessUsage: Sendable, Equatable {
  public let pid: Int32
  /// Which process started it, so a tree can be drawn from a flat list.
  public let parentPID: Int32
  public let name: String
  public let footprint: UInt64
  public let cpuTime: Duration
}
