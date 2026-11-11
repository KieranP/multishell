/// Reads numbered as they begin, and each key's latest to land: one landing
/// after a read begun later has landed would put older data back, so is dropped.
struct LandingOrder<Key: Hashable> {
  private var begun = 0
  private var landed: [Key: Int] = [:]

  mutating func begin() -> Int {
    begun += 1
    return begun
  }

  /// Whether a read may land, recorded as its key's latest when it may. A
  /// later read merely begun does not stop it: its caller may be awaiting it.
  mutating func lands(_ serial: Int, for key: Key) -> Bool {
    guard serial > landed[key, default: 0] else { return false }
    landed[key] = serial
    return true
  }

  /// Whether a read begun later has landed, without this one taking a place:
  /// a failure is no newer list to hold an older success off with.
  func isOvertaken(_ serial: Int, for key: Key) -> Bool {
    serial <= landed[key, default: 0]
  }

  mutating func forget(_ key: Key) {
    landed[key] = nil
  }
}
