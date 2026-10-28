import Foundation
import MultishellAppCore
import SwiftTreeSitter
import Testing

@testable import MultishellHighlight

enum InjectionProbe {
  static func injections(
    in text: String,
    language: HighlightLanguage = .html,
    within keptRanges: [Range<Int>]? = nil,
  ) throws -> [Injection] {
    let grammar = try HighlightGrammars.compile(language)
    let parser = Parser()
    try parser.setLanguage(grammar.language)
    let tree = try #require(
      parser.parse(SyntaxHighlighter.grammarInput(from: text, language: language))
    )
    let found = HighlightInjections.find(
      in: tree,
      text: text as NSString,
      using: try #require(grammar.injectionQuery),
      within: keptRanges,
    )
    return found.injections
  }

  static func languages(
    in text: String,
    language: HighlightLanguage = .html,
  ) throws -> [HighlightLanguage] {
    try injections(in: text, language: language).map(\.language)
  }

  static func range(ofLine line: Int, in text: String) -> Range<Int> {
    var start = 0
    for (index, row) in text.components(separatedBy: "\n").enumerated() {
      if index == line { return start..<(start + row.utf16.count) }
      start += row.utf16.count + 1
    }
    return start..<start
  }
}
