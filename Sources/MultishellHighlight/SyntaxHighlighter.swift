import Foundation
import MultishellAppCore
import SwiftTreeSitter
import Synchronization

/// A whole text's highlighted ranges from one parse and one query; blocking,
/// so callers run it off the main thread. See Docs/design/files.md.
final class SyntaxHighlighter: Sendable {
  static let shared = SyntaxHighlighter()

  private let grammars = Mutex<[HighlightLanguage: CompiledGrammar]>([:])

  /// In pattern order, so applying them in turn lets a later pattern win, as
  /// the queries are written for; parsed as UTF-16.
  func spans(in text: String, language: HighlightLanguage) -> [HighlightSpan] {
    guard let grammar = grammar(for: language) else { return [] }
    let parser = Parser()
    guard (try? parser.setLanguage(grammar.language)) != nil, let tree = parser.parse(text)
    else { return [] }
    var found: [(pattern: Int, span: HighlightSpan)] = []
    let matches = grammar.query.execute(in: tree).resolve(with: Predicate.Context(string: text))
    for match in matches {
      for capture in match.captures {
        guard let name = capture.name, capture.range.length > 0,
          let role = HighlightCaptureRoles.role(forCapture: name, in: language)
        else { continue }
        let range = capture.range.location..<NSMaxRange(capture.range)
        found.append((capture.patternIndex, HighlightSpan(range: range, role: role)))
      }
    }
    return found.enumerated().sorted { first, second in
      first.element.pattern == second.element.pattern
        ? first.offset < second.offset : first.element.pattern < second.element.pattern
    }.map(\.element.span)
  }

  /// `nil` where the grammar would not compile, which a test holds for each.
  private func grammar(for language: HighlightLanguage) -> CompiledGrammar? {
    if let known = grammars.withLock({ $0[language] }) { return known }
    guard let compiled = try? HighlightGrammars.compile(language) else { return nil }
    grammars.withLock { $0[language] = compiled }
    return compiled
  }
}
