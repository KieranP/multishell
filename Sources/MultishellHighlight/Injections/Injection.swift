import Foundation
import MultishellAppCore

/// Part of a file in another language than its own, in UTF-16 offsets from the file's
/// start, parsed inside an uncoloured prefix and suffix that make it read as what it is.
struct Injection {
  let range: Range<Int>
  let language: HighlightLanguage
  let prefix: String
  let suffix: String
  let decodesCharacterReferences: Bool
  let blankedRanges: [Range<Int>]

  init(
    range: Range<Int>,
    language: HighlightLanguage,
    prefix: String = "",
    suffix: String = "",
    decodesCharacterReferences: Bool = false,
    blankedRanges: [Range<Int>] = [],
  ) {
    self.range = range
    self.language = language
    self.prefix = prefix
    self.suffix = suffix
    self.decodesCharacterReferences = decodesCharacterReferences
    self.blankedRanges = blankedRanges
  }

  /// Its text with `blankedRanges`, a fence's quote markers and list indent, as spaces,
  /// so offsets line up.
  func source(in text: NSString) -> String {
    guard !blankedRanges.isEmpty else { return text.substring(with: NSRange(range)) }
    let source = NSMutableString(string: text.substring(with: NSRange(range)))
    for blanked in blankedRanges {
      let inSource = NSRange(blanked.shifted(by: -range.lowerBound))
      let spaces = String(repeating: " ", count: inSource.length)
      source.replaceCharacters(in: inSource, with: spaces)
    }
    return source as String
  }
}
