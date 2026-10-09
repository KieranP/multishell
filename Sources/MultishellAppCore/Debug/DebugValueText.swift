import Foundation
import MultishellCore
import MultishellProcess

/// Debug Info's numbers in words, through the catalogue so a unit can
/// move. Only memory, ByteCountFormatter's, follows the locale; translation.md.
enum DebugValueText {
  /// What a cell shows where there is nothing to measure yet.
  static var noValue: String { t("debug.no-value") }

  static func memory(_ bytes: UInt64) -> String {
    ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .memory)
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
