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
}
