/// Which way a cycle through a list steps, wrapping at either end.
public enum CycleDirection: Equatable, Sendable {
  case next
  case previous
}
