/// Where a PR page Send with checks stands, which its foot says and which keeps
/// a second Send from reading the same logs.
enum HandoffSendPhase: Equatable, Sendable {
  /// Claimed, reading the threads or working out what to send.
  case preparing
  case readingLogs(count: Int)
}
