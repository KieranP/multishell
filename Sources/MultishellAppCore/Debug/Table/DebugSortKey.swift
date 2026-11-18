import Foundation

/// What a debug table row is compared by under one column. One column only
/// ever gives one case.
enum DebugSortKey: Equatable {
  case number(Double)
  case text(String)

  /// Text by `localizedStandardCompare`, so "acme" and "Zed" read A to Z.
  func compare(_ other: Self) -> ComparisonResult {
    switch (self, other) {
    case (.number(let left), .number(let right)):
      left < right ? .orderedAscending : left > right ? .orderedDescending : .orderedSame

    case (.text(let left), .text(let right)):
      left.localizedStandardCompare(right)

    case (.number, .text):
      .orderedAscending

    case (.text, .number):
      .orderedDescending
    }
  }
}
