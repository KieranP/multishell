import Foundation
import MultishellAppCore
import SwiftTreeSitter
import Synchronization

/// A whole text's highlighted ranges from one parse and one query, and one of each
/// per injection; blocking, so callers run it off the main thread. See Docs/design/files.md.
final class SyntaxHighlighter: Sendable {
  static let shared = SyntaxHighlighter()

  private let slots = Mutex<[HighlightLanguage: CompiledGrammarSlot]>([:])
  private let compile: GrammarCompiler

  init(compile: @escaping GrammarCompiler = HighlightGrammars.compile) {
    self.compile = compile
  }

  /// In pattern order so a later pattern wins, then each injection's, all from matches reaching
  /// `keptRanges`, sorted and apart; UTF-16. One highlight's texts share `cache`.
  func spans(
    in text: String,
    language: HighlightLanguage,
    cache: inout HighlightPassCache,
    within keptRanges: [Range<Int>]? = nil,
  ) -> [HighlightSpan] {
    // Every removed row blank leaves nothing to keep, so the parse is skipped.
    guard keptRanges?.isEmpty != true, let grammar = grammar(for: language, in: &cache),
      let parser = parser(for: language, grammar: grammar, in: &cache),
      let tree = parser.parse(text)
    else { return [] }
    return spans(
      of: tree,
      in: text,
      grammar: grammar,
      cache: &cache,
      within: keptRanges,
    )
  }

  private func spans(
    of tree: MutableTree,
    in text: String,
    grammar: CompiledGrammar,
    cache: inout HighlightPassCache,
    within keptRanges: [Range<Int>]? = nil,
  ) -> [HighlightSpan] {
    var captured: [(pattern: Int, span: HighlightSpan)] = []
    let captures = grammar.query.captures(
      in: tree,
      within: keptRanges,
      matching: Predicate.Context(string: text),
    )
    for capture in captures {
      guard capture.range.length > 0, let role = grammar.captureRoles[capture.index] else {
        continue
      }
      let span = HighlightSpan(range: capture.range.integerRange, role: role)
      captured.append((capture.patternIndex, span))
    }
    let inPatternOrder = captured.enumerated().sorted { first, second in
      first.element.pattern == second.element.pattern
        ? first.offset < second.offset : first.element.pattern < second.element.pattern
    }.map(\.element.span)
    guard let injectionQuery = grammar.injectionQuery else { return inPatternOrder }
    let string = text as NSString
    let found = HighlightInjections.find(
      in: tree,
      text: string,
      using: injectionQuery,
      within: keptRanges,
    )
    let keywords = found.keywords.map { HighlightSpan(range: $0, role: .keyword) }
    var injected: [HighlightSpan] = []
    for injection in found.injections where keptRanges?.hasRange(meeting: injection.range) ?? true {
      injected += injectedSpans(of: injection, in: string, cache: &cache)
    }
    return inPatternOrder + injected + keywords
  }

  /// An injection parsed on its own over a plain span, which clears a host's colour
  /// such as an attribute's string; none where its grammar would not parse it.
  private func injectedSpans(
    of injection: Injection,
    in text: NSString,
    cache: inout HighlightPassCache,
  ) -> [HighlightSpan] {
    guard let grammar = grammar(for: injection.language, in: &cache),
      let parser = parser(for: injection.language, grammar: grammar, in: &cache)
    else { return [] }
    let source = text.substring(with: NSRange(injection.range))
    let decodes = injection.decodesCharacterReferences && source.contains("&")
    let decoded = decodes ? CharacterReferences.decoded(source) : nil
    let body = decoded?.text ?? source
    guard let wrapped = WrappedInjection.parsed(body, in: injection, parser: parser) else {
      return []
    }
    let parsed = spans(
      of: wrapped.tree,
      in: wrapped.text,
      grammar: grammar,
      cache: &cache,
    )
    let bodyRange = 0..<body.utf16.count
    let inFile = parsed.compactMap { span -> HighlightSpan? in
      let inBody = span.range.shifted(by: -injection.prefix.utf16.count).clamped(to: bodyRange)
      let inSource = decoded?.sourceRange(of: inBody) ?? inBody
      guard !inSource.isEmpty else { return nil }
      return HighlightSpan(
        range: inSource.shifted(by: injection.range.lowerBound),
        role: span.role,
      )
    }
    return [HighlightSpan(range: injection.range, role: .plain)] + inFile
  }

  private func parser(
    for language: HighlightLanguage,
    grammar: CompiledGrammar,
    in cache: inout HighlightPassCache,
  ) -> Parser? {
    if let known = cache.parsers[language] { return known }
    let parser = Parser()
    let accepted = (try? parser.setLanguage(grammar.language)) != nil ? parser : nil
    cache.parsers.updateValue(accepted, forKey: language)
    return accepted
  }

  /// `nil` where the grammar would not compile, which a test holds for each.
  private func grammar(
    for language: HighlightLanguage,
    in cache: inout HighlightPassCache,
  ) -> CompiledGrammar? {
    if let known = cache.grammars[language] { return known }
    let compiled = slot(for: language).grammar { try? compile(language) }
    cache.grammars.updateValue(compiled, forKey: language)
    return compiled
  }

  private func slot(for language: HighlightLanguage) -> CompiledGrammarSlot {
    slots.withLock { slots in
      if let known = slots[language] { return known }
      let slot = CompiledGrammarSlot()
      slots[language] = slot
      return slot
    }
  }
}
