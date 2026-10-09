import Darwin

/// One process's memory and CPU time as the kernel accounts them: the
/// footprint is what Activity Monitor's Memory column shows.
struct KernelResourceUsage: Sendable, Equatable {
  // The times are in mach ticks, not the nanoseconds the header says: on
  // Apple silicon a tick is 125/3 ns.
  private static let timebase: mach_timebase_info_data_t = {
    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    return timebase
  }()

  let footprint: UInt64
  let cpuTime: Duration

  /// `nil` for a process that has gone or is not ours to read.
  static func of(_ pid: Int32) -> Self? {
    var info = rusage_info_v0()
    guard read(pid, flavor: RUSAGE_INFO_V0, into: &info) else { return nil }
    return Self(
      footprint: info.ri_phys_footprint,
      cpuTime: cpuTime(ofTicks: info.ri_user_time &+ info.ri_system_time),
    )
  }

  /// The largest footprint and CPU time over the process's life, readable
  /// while it is a zombie: how a run too short for any sample is measured.
  static func exitUsage(of pid: Int32) -> ExitUsage? {
    var info = rusage_info_v4()
    guard read(pid, flavor: RUSAGE_INFO_V4, into: &info) else { return nil }
    return ExitUsage(
      pid: pid,
      peakFootprint: info.ri_lifetime_max_phys_footprint,
      cpuTime: cpuTime(ofTicks: info.ri_user_time &+ info.ri_system_time),
    )
  }

  private static func read<Info>(_ pid: Int32, flavor: Int32, into info: inout Info) -> Bool {
    withUnsafeMutablePointer(to: &info) { infoPointer in
      infoPointer.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { usagePointer in
        proc_pid_rusage(pid, flavor, usagePointer)
      }
    } == 0
  }

  private static func cpuTime(ofTicks ticks: UInt64) -> Duration {
    let (product, overflow) = ticks.multipliedReportingOverflow(by: UInt64(timebase.numer))
    let nanoseconds = overflow ? UInt64.max : product / UInt64(max(timebase.denom, 1))
    return .nanoseconds(Int64(clamping: nanoseconds))
  }
}
