import MultishellAppCore

/// Part of a file in another language than its own, in UTF-16 offsets from the file's
/// start, parsed inside an uncoloured prefix and suffix that make it read as what it is.
struct Injection {
  let range: Range<Int>
  let language: HighlightLanguage
  let prefix: String
  let suffix: String
  let decodesCharacterReferences: Bool

  init(
    range: Range<Int>,
    language: HighlightLanguage,
    prefix: String = "",
    suffix: String = "",
    decodesCharacterReferences: Bool = false,
  ) {
    self.range = range
    self.language = language
    self.prefix = prefix
    self.suffix = suffix
    self.decodesCharacterReferences = decodesCharacterReferences
  }
}
