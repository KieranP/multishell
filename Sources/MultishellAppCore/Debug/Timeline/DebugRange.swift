// Declared order is the order allCases gives the UI.
// swiftlint:disable sorted_enum_cases
/// How far back Debug Info looks: the spans a load average is taken over.
public enum DebugRange: CaseIterable, Sendable {
  case oneMinute
  case fiveMinutes
  case fifteenMinutes

  /// One sample a second.
  var sampleCount: Int {
    switch self {
    case .oneMinute: 60
    case .fiveMinutes: 300
    case .fifteenMinutes: 900
    }
  }

  /// Seconds drawn as one point, so a strip draws at most 180 of them.
  var secondsPerSlot: Int {
    switch self {
    case .oneMinute: 1
    case .fiveMinutes: 2
    case .fifteenMinutes: 5
    }
  }

  var slotCount: Int { sampleCount / secondsPerSlot }
}
// swiftlint:enable sorted_enum_cases
