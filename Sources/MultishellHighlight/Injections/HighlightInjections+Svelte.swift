import Foundation
import MultishellAppCore
import SwiftTreeSitter

extension HighlightInjections {
  /// Svelte's compiler's `regex_lang_attribute`, its `(["'])?…\1` as three cases, since ICU
  /// fails a back reference to a group that took no part; see Docs/design/files.md for `(?>`.
  private static let langAttribute = try? NSRegularExpression(
    pattern: #"<!--[\s\S]*?-->|<script\s+"#
      + #"(?:[^>]*|(?>[^=>'"/]+=(?:"[^"]*"|'[^']*'|[^>\s]+)\s+)*)"#
      + #"lang=(?:"([^"' >]+)"|'([^"' >]+)'|([^"' >]+))[^>]*>"#
  )

  /// As Svelte's compiler decides it for the whole file, by its regex over the text: TypeScript
  /// where the first `<script` it matches has exactly `ts`, so `a < b > (c)` is no call elsewhere.
  static func expressionLanguage(in text: NSString) -> HighlightLanguage {
    var lang: String?
    let whole = NSRange(location: 0, length: text.length)
    langAttribute?.enumerateMatches(in: text as String, range: whole) { match, _, stop in
      guard let value = match.flatMap(langValue) else { return }
      lang = text.substring(with: value)
      stop.pointee = true
    }
    return lang == "ts" ? .typeScript : .javaScript
  }

  /// The `lang` value a `<script` match holds; `nil` for a comment, which the regex matches
  /// only so that a `<script` inside one is skipped.
  private static func langValue(in match: NSTextCheckingResult) -> NSRange? {
    (1...3).lazy.map(match.range(at:)).first { $0.location != NSNotFound }
  }

  static func expression(_ node: Node, as language: HighlightLanguage) -> Injection {
    expression(at: node.range.integerRange, as: language)
  }

  static func pattern(_ node: Node, as language: HighlightLanguage) -> Injection {
    pattern(at: node.range.integerRange, as: language)
  }

  /// `load() then value`, its keyword coloured itself since no grammar here has one.
  static func awaitHead(
    _ node: Node,
    in text: NSString,
    as language: HighlightLanguage,
  ) -> HostInjections {
    let start = node.range.location
    let parts = SvelteBlockHead.awaitHead(text.substring(with: node.range))
    return HostInjections(
      injections: [
        expression(at: parts.promise.shifted(by: start), as: language),
        parts.pattern.map { pattern(at: $0.shifted(by: start), as: language) },
      ].compactMap(\.self),
      keywords: parts.keyword.map { [$0.shifted(by: start)] } ?? [],
    )
  }

  /// `item, i (item.id)`, its key read apart so `i (…)` is no call.
  static func eachParameter(
    _ node: Node,
    in text: NSString,
    as language: HighlightLanguage,
  ) -> HostInjections {
    let start = node.range.location
    let parts = SvelteBlockHead.eachParameter(text.substring(with: node.range))
    return HostInjections(
      injections: [
        pattern(at: parts.pattern.shifted(by: start), as: language),
        parts.key.map { expression(at: $0.shifted(by: start), as: language) },
      ].compactMap(\.self)
    )
  }

  /// `row(a: number)` read as a function's head, so its name and types colour.
  static func snippetSignature(_ snippet: Node, as language: HighlightLanguage) -> Injection? {
    guard let name = snippet.children.first(where: { $0.nodeType == "snippet_name" }),
      let close = Array(snippet.children).last(where: { $0.nodeType == ")" })
    else { return nil }
    return Injection(
      range: name.range.integerRange.lowerBound..<close.range.integerRange.upperBound,
      language: language,
      prefix: "function ",
      suffix: " {}",
    )
  }

  /// In parentheses, which a statement cannot start with, so `{a: 1}` reads as an
  /// object rather than a block holding a label.
  private static func expression(at range: Range<Int>, as language: HighlightLanguage) -> Injection
  {
    Injection(range: range, language: language, prefix: "(", suffix: ")")
  }

  /// As an arrow function's parameters: `{ a = 1 }` is a pattern there, but in
  /// parentheses alone it is an object literal that does not parse.
  private static func pattern(at range: Range<Int>, as language: HighlightLanguage) -> Injection {
    Injection(range: range, language: language, prefix: "(", suffix: ") => 0")
  }
}
