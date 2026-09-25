import Foundation

/// Parses the hex strings themes are written in. In the core so both
/// frontends and both terminal backends read a theme file the same way.
enum HexColor {
  /// Accepts `#rgb`, `#rrggbb`, and either without the `#`. A trailing alpha
  /// is read and ignored: a terminal cell has none.
  static func parse(_ text: String) -> RGB? {
    // Hand-edited theme files pick up stray spaces; grey for the whole
    // palette would be a harsh price for one.
    var digits = Substring(text.trimmingCharacters(in: .whitespaces))
    if digits.hasPrefix("#") { digits = digits.dropFirst() }

    switch digits.count {
    case 3, 4:
      let expanded = digits.prefix(3).flatMap { [$0, $0] }
      return parseSixDigits(String(expanded), alpha: digits.dropFirst(3))
    case 6, 8:
      return parseSixDigits(String(digits.prefix(6)), alpha: digits.dropFirst(6))
    default:
      return nil
    }
  }

  private static func parseSixDigits(_ digits: String, alpha: Substring) -> RGB? {
    guard alpha.allSatisfy(\.isHexDigit) else { return nil }
    return parseSixDigits(digits)
  }

  private static func parseSixDigits(_ digits: String) -> RGB? {
    // `UInt32(_:radix:)` accepts a leading sign, which is not a colour.
    guard digits.allSatisfy(\.isHexDigit), let value = UInt32(digits, radix: 16) else {
      return nil
    }
    return RGB(
      red: UInt8((value >> 16) & 0xFF),
      green: UInt8((value >> 8) & 0xFF),
      blue: UInt8(value & 0xFF)
    )
  }
}
