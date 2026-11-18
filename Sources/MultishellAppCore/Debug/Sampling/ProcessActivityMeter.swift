import MultishellProcess

/// The app's disk and wakeup counters since the last reading. The first
/// reading has nothing to count from and reads zero, as the CPU's does.
struct ProcessActivityMeter {
  private var lastActivity: ProcessActivity?

  mutating func takeReading(of activity: ProcessActivity?) -> DebugActivityCounts {
    defer { if let activity { lastActivity = activity } }
    guard let activity, let lastActivity else { return .zero }
    return DebugActivityCounts(
      diskBytesRead: activity.diskBytesRead.subtractingFlooredAtZero(lastActivity.diskBytesRead),
      diskBytesWritten: activity.diskBytesWritten.subtractingFlooredAtZero(
        lastActivity.diskBytesWritten
      ),
      interruptWakeups: activity.interruptWakeups.subtractingFlooredAtZero(
        lastActivity.interruptWakeups
      ),
      packageIdleWakeups: activity.packageIdleWakeups.subtractingFlooredAtZero(
        lastActivity.packageIdleWakeups
      ),
    )
  }
}
