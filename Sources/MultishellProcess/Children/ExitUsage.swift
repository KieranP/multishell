/// What a child process used over its whole life, read as it exited.
public struct ExitUsage: Sendable, Equatable {
  public let pid: Int32
  /// Its own largest footprint, its children left out.
  public let peakFootprint: UInt64
  public let cpuTime: Duration

  init(pid: Int32, peakFootprint: UInt64, cpuTime: Duration) {
    self.pid = pid
    self.peakFootprint = peakFootprint
    self.cpuTime = cpuTime
  }
}
