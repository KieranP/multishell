import Foundation
import MultishellCore
import MultishellProcess

/// Debug Info's numbers in words, through the catalogue so a unit can
/// move. Only memory follows the locale; translation.md.
enum DebugValueText {
  /// What a cell shows where there is nothing to measure yet.
  static var noValue: String { t("debug.no-value") }

  private static let memoryUnits: [ByteCountFormatter.Units] = [
    .useKB, .useMB, .useGB, .useTB, .usePB,
  ]

  static func memory(_ bytes: UInt64) -> String {
    memory(bytes, locale: .autoupdatingCurrent)
  }

  /// Two places, where ByteCountFormatter drops trailing zeros and gives MB one,
  /// and never four whole digits, which overflow the debug tables' columns.
  static func memory(_ bytes: UInt64, locale: Locale) -> String {
    var count = Double(bytes)
    var unit: ByteCountFormatter.Units?
    for nextUnit in memoryUnits where (count * 100).rounded() >= 100_000 {
      count /= 1024
      unit = nextUnit
    }
    guard let unit else { return compactMemory(bytes) }
    let figure = count.formatted(.number.precision(.fractionLength(2)).locale(locale))
    return "\(figure) \(memoryUnitName(unit))"
  }

  /// ByteCountFormatter's own form, trailing zeros dropped, for a lone figure
  /// with no column to line up in: the sidebar's cells, which "999.99 MB" overflows.
  static func compactMemory(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
  }

  private static func memoryUnitName(_ unit: ByteCountFormatter.Units) -> String {
    let formatter = ByteCountFormatter()
    formatter.countStyle = .memory
    formatter.allowedUnits = unit
    formatter.includesCount = false
    return formatter.string(fromByteCount: 0)
  }

  static func framesPerSecond(_ value: Double) -> String {
    t("debug.fps", wholeNumber(value))
  }

  static func percent(_ value: Double) -> String {
    t("debug.percent", wholeNumber(value))
  }

  static func perSecond(_ value: Double) -> String {
    t("debug.per-second", rate(value))
  }

  /// A rate in bytes, rounded to whole bytes.
  private static func bytes(_ value: Double) -> String {
    memory(wholeBytes(value))
  }

  static func compactBytes(_ value: Double) -> String {
    compactMemory(wholeBytes(value))
  }

  private static func wholeBytes(_ value: Double) -> UInt64 {
    UInt64(max(value, 0).rounded())
  }

  static func bytesPerSecond(_ value: Double) -> String {
    t("debug.per-second", bytes(value))
  }

  /// Tenths only where a rate over several seconds comes to a fraction.
  private static func rate(_ value: Double) -> String {
    value == value.rounded() ? wholeNumber(value) : String(format: "%.1f", value)
  }

  /// Milliseconds under a second, seconds to one place above it.
  static func duration(_ duration: Duration) -> String {
    let seconds = duration.inSeconds
    guard seconds >= 1 else { return t("debug.milliseconds", wholeNumber(seconds * 1000)) }
    return t("debug.seconds", String(format: "%.1f", seconds))
  }

  private static func wholeNumber(_ value: Double) -> String {
    String(Int(value.rounded()))
  }
}
