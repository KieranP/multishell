import Foundation

extension StringProtocol {
  /// Folded as `foldedContains` folds, for many paths matched against one text:
  /// `prefoldedContains` then finds the same, and inside a flag or ligature too.
  var foldedForMatching: String {
    folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
      .precomposedStringWithCanonicalMapping
  }

  /// Contains `text`, ignoring case and accents, by Unicode's own rules
  /// rather than the reader's alphabet; see Docs/design/translation.md.
  func foldedContains(_ text: some StringProtocol) -> Bool {
    guard !text.isEmpty else { return true }
    return range(of: text, options: [.caseInsensitive, .diacriticInsensitive], locale: nil) != nil
  }
}
