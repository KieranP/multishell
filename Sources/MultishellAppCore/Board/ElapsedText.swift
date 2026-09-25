import Foundation
import MultishellCore

/// How long, in the two lengths the board needs: a glance for the corner,
/// seconds for the message line. Both take the interval, reading no clock.
enum ElapsedText {
  private static let minute = 60.0
  private static let hour = 3600.0
  /// `Int(_: Double)` traps above this, and the board renders whatever
  /// duration a report carried; see Docs/design/agents.md.
  private static let renderable = Double(Int.max)

  /// A glance: `41s`, `12m`, `1h 05m`. A negative interval reads as nothing
  /// rather than a wrong number.
  static func short(_ interval: TimeInterval) -> String? {
    guard interval.isFinite, interval >= 0, interval < renderable else { return nil }
    if interval < minute { return t("elapsed.seconds", Int(interval)) }
    if interval < hour { return t("elapsed.minutes", Int(interval / minute)) }
    let hours = Int(interval / hour)
    let minutes = Int((interval - Double(hours) * hour) / minute)
    return t("elapsed.hours", hours, minutes)
  }

  /// Clamped, the board's clock lagging by up to a tick, which `short` would
  /// read as a clock run back.
  static func short(since: Date?, now: Date) -> String? {
    guard let since else { return nil }
    return short(max(now, since).timeIntervalSince(since))
  }

  /// A command's runtime: `0.4s`, `9s`, `1m 12s`. Under ten seconds it keeps
  /// a decimal, where a prompt and a build differ.
  static func precise(_ interval: TimeInterval) -> String? {
    guard interval.isFinite, interval >= 0, interval < renderable else { return nil }
    if interval < 10 { return t("elapsed.seconds-precise", interval) }
    if interval < minute { return t("elapsed.seconds", Int(interval)) }
    if interval < hour {
      let minutes = Int(interval / minute)
      return t("elapsed.minutes-seconds", minutes, Int(interval - Double(minutes) * minute))
    }
    return short(interval)
  }
}
