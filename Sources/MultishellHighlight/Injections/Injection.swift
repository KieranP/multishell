import Foundation
import MultishellAppCore

/// Part of a file in another language, in UTF-16 offsets, parsed inside an uncoloured prefix
/// and suffix; its ascending `hostRanges` are blanked for the parse and keep the file's colours.
struct Injection {
  let range: Range<Int>
  let language: HighlightLanguage
  let prefix: String
  let suffix: String
  let decodesCharacterReferences: Bool
  let blankedRanges: [Range<Int>]
  let hostRanges: [Range<Int>]

  /// Where its colours land: `range` less `hostRanges`.
  var injectedRanges: [Range<Int>] { range.subtracting(hostRanges) }

  init(
    range: Range<Int>,
    language: HighlightLanguage,
    prefix: String = "",
    suffix: String = "",
    decodesCharacterReferences: Bool = false,
    blankedRanges: [Range<Int>] = [],
    hostRanges: [Range<Int>] = [],
  ) {
    self.range = range
    self.language = language
    self.prefix = prefix
    self.suffix = suffix
    self.decodesCharacterReferences = decodesCharacterReferences
    self.blankedRanges = blankedRanges
    self.hostRanges = hostRanges
  }

  /// Whether any of `injectedRanges` meets one of `keptRanges`, ascending.
  func reaches(any keptRanges: [Range<Int>]) -> Bool {
    injectedRanges.contains { keptRanges.hasRange(meeting: $0) }
  }

  /// Its text with `blankedRanges`, a quote's markers and list indent, and `hostRanges`
  /// as spaces, so offsets line up.
  func source(in text: NSString) -> String {
    let blanks = blankedRanges + hostRanges
    guard !blanks.isEmpty else { return text.substring(with: NSRange(range)) }
    let source = NSMutableString(string: text.substring(with: NSRange(range)))
    for blanked in blanks {
      let inSource = NSRange(blanked.shifted(by: -range.lowerBound))
      let spaces = String(repeating: " ", count: inSource.length)
      source.replaceCharacters(in: inSource, with: spaces)
    }
    return source as String
  }
}
