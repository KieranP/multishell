/// How many cells a terminal draws a character in: two for an emoji or an East
/// Asian wide character, one for the rest. An estimate of libghostty's table.
enum TerminalCellWidth {
  private static let wideRanges: [ClosedRange<UInt32>] = [
    0x1100...0x115F, 0x2E80...0x303E, 0x3041...0x33FF, 0x3400...0x4DBF, 0x4E00...0x9FFF,
    0xA000...0xA4CF, 0xAC00...0xD7A3, 0xF900...0xFAFF, 0xFE30...0xFE4F, 0xFF00...0xFF60,
    0xFFE0...0xFFE6, 0x1F300...0x1F64F, 0x1F900...0x1F9FF, 0x20000...0x3FFFD,
  ]

  static func cells(of character: Character) -> Int {
    guard let base = character.unicodeScalars.first else { return 1 }
    let isWide =
      base.properties.isEmojiPresentation
      || character.unicodeScalars.contains("\u{FE0F}")
      || wideRanges.contains { $0.contains(base.value) }
    return isWide ? 2 : 1
  }
}
