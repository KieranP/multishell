/// Why a child was ended by this side rather than exiting on its own.
public enum ProcessStop: Equatable, Sendable {
  /// It was still running when `timeout` ran out.
  case timedOut(after: Duration)
  /// `ProcessStopper.stop()` was called: the user asked.
  case byUser
}
