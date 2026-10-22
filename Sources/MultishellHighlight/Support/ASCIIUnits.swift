import Foundation

/// UTF-16 units and classes more than one of the highlighter's scanners compares,
/// and the one character set Foundation's trimming takes; others stay local.
enum ASCIIUnits {
  /// HTML's ASCII whitespace, form feed included; JavaScript's U+000B, U+00A0
  /// and U+FEFF are not in it, so a block head spaced with them is not cut.
  private static let whitespaceCharacters = " \t\n\u{0C}\r"
  static let whitespace = Set(whitespaceCharacters.utf16)
  static let whitespaceCharacterSet = CharacterSet(charactersIn: whitespaceCharacters)
  static let backslash = UInt16(UInt8(ascii: "\\"))
  static let dot = UInt16(UInt8(ascii: "."))
  /// Set in an ASCII letter's unit, it gives the lowercase letter.
  static let lowercaseBit: UInt16 = 0x20

  /// Plain range checks rather than `Character`'s, as scanners call these on
  /// every unit of a file.
  static func isLetter(_ unit: UInt16) -> Bool {
    isUppercaseLetter(unit) || (0x61...0x7A).contains(unit)
  }

  static func isUppercaseLetter(_ unit: UInt16) -> Bool { (0x41...0x5A).contains(unit) }

  static func isDigit(_ unit: UInt16) -> Bool { (0x30...0x39).contains(unit) }
}
