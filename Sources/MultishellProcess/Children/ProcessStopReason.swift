/// Why a child was ended by this side rather than exiting on its own.
public enum ProcessStopReason: Equatable, Sendable {
  /// `ProcessStopper.stop()` was called: the user asked.
  case byUser
  /// It was still running when `timeout` ran out.
  case timedOut(after: Duration)
}
