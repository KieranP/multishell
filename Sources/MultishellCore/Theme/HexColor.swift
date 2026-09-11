import Foundation

/// Parses the hex strings themes are written in.
///
/// Lives in the core rather than in a GUI so both frontends, and both terminal
/// backends, share one interpretation of a theme file.
public enum HexColor {
  /// Accepts `#rgb`, `#rrggbb`, and either without the leading `#`. A
  /// trailing alpha (`#rgba`, `#rrggbbaa`), which themes exported from other
  /// tools often carry, is read and ignored: a terminal cell has no alpha,
  /// and grey for the slot would be the wrong colour rather than a warning.
  public static func parse(_ text: String) -> RGB? {
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

extension Theme {
  /// The 16 ANSI colours, with any unparsable entry falling back to grey so
  /// a hand-edited theme file cannot leave a terminal unpaintable.
  public var ansiRGB: [RGB] {
    ansi.map { HexColor.parse($0) ?? RGB(red: 128, green: 128, blue: 128) }
  }

  public var backgroundRGB: RGB { HexColor.parse(background) ?? RGB(red: 0, green: 0, blue: 0) }
  public var foregroundRGB: RGB {
    HexColor.parse(foreground) ?? RGB(red: 255, green: 255, blue: 255)
  }
  public var cursorRGB: RGB { HexColor.parse(cursor) ?? foregroundRGB }
  public var selectionRGB: RGB {
    HexColor.parse(selectionBackground) ?? RGB(red: 64, green: 96, blue: 144)
  }

  /// The line round the focused pane, or `nil` for no line.
  ///
  /// The three spellings of the key: a colour is that colour, an empty
  /// string is no ring, and the key left out is the selection colour, which
  /// is what the app drew before the key existed. A colour that will not
  /// parse reads as the key left out and not as no ring, so a typo costs
  /// the colour rather than silently removing the thing it was setting.
  public var focusRingRGB: RGB? {
    guard let focusRing else { return selectionRGB }
    let text = focusRing.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { return nil }
    return HexColor.parse(text) ?? selectionRGB
  }
}
