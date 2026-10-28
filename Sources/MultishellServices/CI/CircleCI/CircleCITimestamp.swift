import Foundation

/// CircleCI's times: `2026-10-27 01:05 UTC` as 1.11 prints them, else ISO 8601
/// with or without fractional seconds.
enum CircleCITimestamp {
  private static let hour = Date.FormatStyle.Symbol.VerbatimHour.twoDigits(
    clock: .twentyFourHour,
    hourCycle: .zeroBased,
  )
  private static let printed = Date.ParseStrategy(
    format:
      "\(year: .defaultDigits)-\(month: .twoDigits)-\(day: .twoDigits) \(hour: hour):\(minute: .twoDigits) UTC",
    timeZone: .gmt,
  )

  static func date(from text: String) -> Date? {
    (try? Date(text, strategy: printed))
      ?? (try? Date(text, strategy: .iso8601))
      ?? (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
  }
}
