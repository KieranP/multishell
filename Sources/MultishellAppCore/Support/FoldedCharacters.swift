/// A text folded for matching, one character at a time, each knowing the
/// character of the text it came from: ß folds to two, both its.
struct FoldedCharacters {
  let characters: [String]
  /// For each of `characters`, the offset of the text's character it folds.
  let sourceOffsets: [Int]

  /// One fold of the whole text where no character's fold changed the count,
  /// one Foundation call where folding each character took one apiece.
  init(_ text: String) {
    let folded = text.foldedForMatching
    guard folded.count != text.count else {
      characters = folded.map(String.init)
      sourceOffsets = Array(characters.indices)
      return
    }
    var characters: [String] = []
    var sourceOffsets: [Int] = []
    for (offset, character) in text.enumerated() {
      for piece in String(character).foldedForMatching {
        characters.append(String(piece))
        sourceOffsets.append(offset)
      }
    }
    self.characters = characters
    self.sourceOffsets = sourceOffsets
  }
}
