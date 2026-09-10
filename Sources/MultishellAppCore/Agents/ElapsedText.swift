import Foundation

/// How long, in the two lengths the board needs.
///
/// A card's corner says how long the pane has been in its column, where the
/// figure is read at a glance and a second's precision is noise; its message
/// line says how long a finished command took, where the seconds are the
/// point. Both take the interval, so nothing here reads a clock.
public enum ElapsedText {
  private static let minute = 60.0
  private static let hour = 3600.0

  /// A glance: `41s`, `12m`, `1h 05m`. Negative and non-finite intervals
  /// read as nothing rather than as a wrong number, a clock that moved
  /// backwards being the usual cause.
  public static func short(_ interval: TimeInterval) -> String? {
    guard interval.isFinite, interval >= 0 else { return nil }
    if interval < minute { return "\(Int(interval))s" }
    if interval < hour { return "\(Int(interval / minute))m" }
    let hours = Int(interval / hour)
    let minutes = Int((interval - Double(hours) * hour) / minute)
    return String(format: "%dh %02dm", hours, minutes)
  }

  public static func short(since: Date?, now: Date) -> String? {
    guard let since else { return nil }
    return short(now.timeIntervalSince(since))
  }

  /// A command's runtime: `0.4s`, `9s`, `1m 12s`, `1h 05m`. Under ten
  /// seconds it keeps a decimal, which is where the difference between a
  /// prompt and a build is.
  public static func precise(_ interval: TimeInterval) -> String? {
    guard interval.isFinite, interval >= 0 else { return nil }
    if interval < 10 { return String(format: "%.1fs", interval) }
    if interval < minute { return "\(Int(interval))s" }
    if interval < hour {
      let minutes = Int(interval / minute)
      return "\(minutes)m \(Int(interval - Double(minutes) * minute))s"
    }
    return short(interval)
  }
}
