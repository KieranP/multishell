import Foundation

/// Two dates in order, newest or oldest first, a date nobody knows going last
/// either way: the sidebar's sorts, the board's columns and the switcher's.
enum DateOrder {
  /// `nil` where the dates cannot separate the two, for the caller's tie-break.
  static func precedes(_ a: Date?, _ b: Date?, newestFirst: Bool) -> Bool? {
    if (a == nil) != (b == nil) { return b == nil }
    guard let a, let b, a != b else { return nil }
    return newestFirst ? a > b : a < b
  }
}
