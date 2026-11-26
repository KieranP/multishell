import Foundation

/// Every match of a find text, case ignored, apart and in UTF-16 units; ASCII on
/// both sides is one pass over the bytes. Why: Docs/design/files/file-tabs.md.
enum CaseInsensitiveMatches {
  static func ranges(of findText: String, in text: String) -> [Range<Int>] {
    guard !findText.isEmpty else { return [] }
    return asciiRanges(of: findText, in: text) ?? foundationRanges(of: findText, in: text)
  }

  /// `nil` where either holds a byte past ASCII, whose case and composed forms
  /// only Foundation's search knows.
  private static func asciiRanges(of findText: String, in text: String) -> [Range<Int>]? {
    let pattern = findText.utf8.map(lowercased)
    guard pattern.allSatisfy({ $0 < 0x80 }) else { return nil }
    var text = text
    let folded: [UInt8]? = text.withUTF8 { bytes in
      bytes.allSatisfy { $0 < 0x80 } ? bytes.map(lowercased) : nil
    }
    guard let folded else { return nil }
    var ranges: [Range<Int>] = []
    // Leftmost first, each match ending where the next may start, as Foundation's search goes.
    for start in folded.startsOfOccurrences(of: pattern, by: ==)
    where start >= (ranges.last?.upperBound ?? 0) {
      ranges.append(start..<(start + pattern.count))
    }
    return ranges
  }

  private static func lowercased(_ byte: UInt8) -> UInt8 {
    (0x41...0x5A).contains(byte) ? byte + 0x20 : byte
  }

  private static func foundationRanges(of findText: String, in text: String) -> [Range<Int>] {
    let searched = text as NSString
    var ranges: [Range<Int>] = []
    var from = 0
    while from < searched.length {
      let found = searched.range(
        of: findText,
        options: [.caseInsensitive],
        range: NSRange(location: from, length: searched.length - from),
      )
      guard found.location != NSNotFound, found.length > 0 else { break }
      ranges.append(found.integerRange)
      from = NSMaxRange(found)
    }
    return ranges
  }
}
