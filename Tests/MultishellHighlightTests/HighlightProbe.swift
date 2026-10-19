import Foundation
import MultishellAppCore
import Testing

@testable import MultishellHighlight

enum HighlightProbe {
  static func role(of word: String, in text: String, spans: [HighlightSpan]) -> HighlightRole? {
    let found = (text as NSString).range(of: word)
    guard found.location != NSNotFound else {
      Issue.record("\(word) is not in the text")
      return nil
    }
    let range = found.integerRange
    let covering = spans.filter { span in
      span.range.lowerBound <= range.lowerBound && span.range.upperBound >= range.upperBound
    }
    return covering.last?.role
  }

  static func role(
    of word: String,
    in text: String,
    language: HighlightLanguage,
  ) -> HighlightRole? {
    role(of: word, in: text, spans: spans(in: text, language: language))
  }

  static func spans(
    in text: String,
    language: HighlightLanguage,
    highlighter: SyntaxHighlighter = .shared,
  ) -> [HighlightSpan] {
    var cache = HighlightPassCache()
    return highlighter.spans(in: text, language: language, cache: &cache)
  }
}
