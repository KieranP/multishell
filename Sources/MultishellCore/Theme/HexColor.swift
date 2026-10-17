import Foundation

/// Parses the hex strings themes are written in. In the core so the app and
/// the terminal engine read a theme file the same way.
enum HexColor {
  private static let space = UInt8(ascii: " ")
  private static let tab = UInt8(ascii: "\t")
  private static let hash = UInt8(ascii: "#")

  /// `#rgb`, `#rgba`, `#rrggbb` or `#rrggbbaa`, the `#` optional. Read on every
  /// render, so it scans the bytes in place; see appearance.md.
  static func parse(_ text: String) -> RGB? {
    var utf8 = Substring(text).utf8[...]
    // Hand-edited theme files pick up stray spaces; the base theme's colour
    // in place of the one written would be a harsh price for one.
    while let first = utf8.first, first == space || first == tab { utf8 = utf8.dropFirst() }
    while let last = utf8.last, last == space || last == tab { utf8 = utf8.dropLast() }
    if utf8.first == hash { utf8 = utf8.dropFirst() }

    var digits: UInt32 = 0
    var count = 0
    for byte in utf8 {
      guard count < 8, let nibble = nibble(byte) else { return nil }
      digits = digits << 4 | UInt32(nibble)
      count += 1
    }
    switch count {
    case 3, 4:
      // The nth digit from the left, written twice: `f` reads as `ff`.
      func doubled(_ index: Int) -> UInt8 {
        let digit = UInt8(truncatingIfNeeded: digits >> (4 * (count - 1 - index)) & 0xF)
        return digit << 4 | digit
      }
      return RGB(
        red: doubled(0),
        green: doubled(1),
        blue: doubled(2),
        alpha: count == 4 ? doubled(3) : 255,
      )

    case 6, 8:
      func pair(_ index: Int) -> UInt8 {
        UInt8(truncatingIfNeeded: digits >> (8 * (count / 2 - 1 - index)))
      }
      return RGB(red: pair(0), green: pair(1), blue: pair(2), alpha: count == 8 ? pair(3) : 255)

    default:
      return nil
    }
  }

  /// One hex digit's value; `nil` for anything else, a sign included.
  private static func nibble(_ byte: UInt8) -> UInt8? {
    switch byte {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): byte - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): byte - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): byte - UInt8(ascii: "A") + 10
    default: nil
    }
  }
}
