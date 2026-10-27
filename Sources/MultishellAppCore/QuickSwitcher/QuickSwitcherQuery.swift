/// The quick switcher's typed text as words, each folded once by Unicode's
/// rules, as the sidebar filter folds; see Docs/design/translation.md.
struct QuickSwitcherQuery: Equatable, Sendable {
  /// Each word as its folded characters, ß as the two it folds to.
  let words: [[String]]
  /// Each word folded whole, for the substring search over paths.
  let foldedWords: [String]

  var isEmpty: Bool { words.isEmpty }

  init(_ text: String) {
    foldedWords = text.split(whereSeparator: \.isWhitespace).map(\.foldedForMatching)
    words = foldedWords.map { $0.map(String.init) }
  }
}
