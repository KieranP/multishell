import MultishellProcess

// Declared mildest first, so `max` reads as the worse of two.
// swiftlint:disable sorted_enum_cases
/// How a tile's value is coloured: plain, a caution, or an alarm.
public enum DebugValueTone: Sendable, Comparable {
  case normal
  case caution
  case alarm

  init(_ smoothness: Smoothness) {
    switch smoothness {
    case .smooth: self = .normal
    case .hitched: self = .caution
    case .stalled: self = .alarm
    }
  }

  init(_ pressure: MemoryPressureLevel) {
    switch pressure {
    case .normal: self = .normal
    case .warning: self = .caution
    case .critical: self = .alarm
    }
  }
}
// swiftlint:enable sorted_enum_cases
