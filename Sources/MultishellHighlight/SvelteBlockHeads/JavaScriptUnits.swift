/// UTF-16 units the Svelte block-head scanner and its cuts compare, a pair kept together
/// where only one of it is shared.
enum JavaScriptUnits {
  static let openParenthesis = UInt16(UInt8(ascii: "("))
  static let closeParenthesis = UInt16(UInt8(ascii: ")"))
  static let closingBrackets = Set(")]}".utf16)
  static let quotes = Set("\"'`".utf16)
  private static let wordMarks = Set("_$".utf16)

  /// Letters, digits, `_` and `$`, any non-ASCII unit counting as a letter.
  static func isWordUnit(_ unit: UInt16) -> Bool {
    unit >= 128 || ASCIIUnits.isLetter(unit) || ASCIIUnits.isDigit(unit) || wordMarks.contains(unit)
  }
}
