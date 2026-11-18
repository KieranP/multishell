/// What the app read from and wrote to disk, and how often it woke a core,
/// over one sample.
struct DebugActivityCounts: Sendable, Equatable {
  static let zero = Self(
    diskBytesRead: 0,
    diskBytesWritten: 0,
    interruptWakeups: 0,
    packageIdleWakeups: 0,
  )

  let diskBytesRead: UInt64
  let diskBytesWritten: UInt64
  let interruptWakeups: UInt64
  let packageIdleWakeups: UInt64
}
