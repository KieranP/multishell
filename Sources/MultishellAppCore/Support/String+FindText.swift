extension String {
  /// Something to find within one line, the most the engine matches across.
  var isFindableOnOneLine: Bool {
    !contains(where: \.isNewline) && contains(where: { !$0.isWhitespace })
  }

  /// The text a selection dragged past its last letter means, as the copy key
  /// trims it; libghostty's read keeps the spaces.
  var withoutTrailingWhitespace: String {
    guard let last = lastIndex(where: { !$0.isWhitespace }) else { return "" }
    return String(self[...last])
  }

  /// The engine's own test of a search left as it is, `std.ascii.eqlIgnoreCase`.
  func isSameFindText(as other: String) -> Bool {
    func folded(_ byte: UInt8) -> UInt8 { (65...90).contains(byte) ? byte + 32 : byte }
    return utf8.count == other.utf8.count
      && zip(utf8, other.utf8).allSatisfy { folded($0) == folded($1) }
  }
}
