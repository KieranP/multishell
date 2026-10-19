import MultishellAppCore
import Testing

@testable import MultishellHighlight

@Suite
struct HighlightGrammarsTests {
  @Test func everyGrammarCompilesWithItsQuery() throws {
    for language in HighlightLanguage.allCases {
      _ = try HighlightGrammars.compile(language)
    }
  }

  @Test func everyInjectionQueryCompilesWhereALanguageHasOne() throws {
    for language in HighlightLanguage.allCases {
      guard let host = MarkupHost(language) else { continue }
      let grammar = try HighlightGrammars.compile(language)
      _ = try HighlightInjections.query(for: host, in: grammar.language)
    }
  }
}
