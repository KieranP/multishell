import Darwin

/// What a process has read and written to disk, and how often it woke a core,
/// since it started, with its largest footprint: counters a meter turns into rates.
public struct ProcessActivity: Sendable, Equatable {
  public let diskBytesRead: UInt64
  public let diskBytesWritten: UInt64
  /// Wakeups from an interrupt or a timer.
  public let interruptWakeups: UInt64
  /// Those of the interrupt wakeups that brought the whole processor package
  /// out of idle, so already counted in them.
  public let packageIdleWakeups: UInt64
  public let peakFootprint: UInt64

  /// `nil` for a process that has gone or is not ours to read.
  public static func of(_ pid: Int32) -> Self? {
    var info = rusage_info_v4()
    guard KernelResourceUsage.read(pid, flavor: RUSAGE_INFO_V4, into: &info) else { return nil }
    return Self(
      diskBytesRead: info.ri_diskio_bytesread,
      diskBytesWritten: info.ri_diskio_byteswritten,
      interruptWakeups: info.ri_interrupt_wkups,
      packageIdleWakeups: info.ri_pkg_idle_wkups,
      peakFootprint: info.ri_lifetime_max_phys_footprint,
    )
  }
}
