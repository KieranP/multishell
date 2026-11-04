/// Which way a step through a list goes; whether it wraps at an end is the caller's.
public enum CycleDirection: Codable, Equatable, Sendable {
  case next
  case previous
}
