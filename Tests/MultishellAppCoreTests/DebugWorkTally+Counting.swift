@testable import MultishellAppCore

extension DebugWorkTally {
  /// `count` runs that took no time, for a test that only counts them.
  static func counting(_ count: Int) -> Self {
    (0..<count).reduce(into: Self.empty) { tally, _ in tally.add(.zero) }
  }
}
