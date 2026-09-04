import Foundation

public struct RGB: Hashable, Sendable {
  public let red: UInt8
  public let green: UInt8
  public let blue: UInt8

  public init(red: UInt8, green: UInt8, blue: UInt8) {
    self.red = red
    self.green = green
    self.blue = blue
  }

  /// Mixes towards `other`, where 0 is self and 1 is `other`.
  public func blended(with other: RGB, amount: Double) -> RGB {
    let ratio = min(max(amount, 0), 1)
    func mix(_ a: UInt8, _ b: UInt8) -> UInt8 {
      UInt8((Double(a) * (1 - ratio) + Double(b) * ratio).rounded())
    }
    return RGB(
      red: mix(red, other.red), green: mix(green, other.green), blue: mix(blue, other.blue))
  }

  public static let white = RGB(red: 255, green: 255, blue: 255)
  public static let black = RGB(red: 0, green: 0, blue: 0)
}

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
}
