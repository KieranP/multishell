import Darwin

// Declared mildest first: the raw values order the levels.
// swiftlint:disable sorted_enum_cases
/// How hard macOS is pressed for memory, system-wide: past normal it starts
/// taking back what processes freed and compressing what they hold.
public enum MemoryPressureLevel: Int, Sendable, Comparable {
  case normal
  case warning
  case critical

  /// The kernel's levels are bit flags: 1, 2 and 4.
  init?(kernelLevel: Int32) {
    switch kernelLevel {
    case 1: self = .normal
    case 2: self = .warning
    case 4: self = .critical
    default: return nil
    }
  }

  /// `nil` where the kernel would not say.
  public static func current() -> Self? {
    var level: Int32 = 0
    var size = MemoryLayout<Int32>.size
    guard sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 else {
      return nil
    }
    return Self(kernelLevel: level)
  }

  public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}
// swiftlint:enable sorted_enum_cases
