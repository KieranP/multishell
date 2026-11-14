import Foundation

/// A count of lines as `+N` and `−N` show it: grouped from five digits, where
/// `+16621` was hard to read, and plain below, where `+1,204` reads no easier.
public enum LineCountText {
  private static let groupedFrom = 10_000

  public static func shown(_ count: Int, locale: Locale = .current) -> String {
    guard abs(count) >= groupedFrom else { return String(count) }
    return count.formatted(.number.grouping(.automatic).locale(locale))
  }
}
