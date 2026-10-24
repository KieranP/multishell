import Foundation

/// The name in what an agent printed: its first line with words, quotes,
/// markdown, escapes and a label taken off, cut to fit a sidebar row.
enum AutoRenameReply {
  /// Two lines of a narrow sidebar row, the name truncating past it anyway.
  static let maximumLength = 48

  private static let quotePairs: [Character: Character] = [
    "\"": "\"", "'": "'", "“": "”", "‘": "’", "«": "»",
  ]
  private static let markdownMarks: Set<Character> = ["*", "_", "`"]
  static func name(from reply: String) -> String? {
    PrintableText.of(reply).split(whereSeparator: \.isNewline).lazy
      .map { cleaned(String($0)) }
      .first(where: hasWords)
      .map(cut)
  }

  private static func hasWords(_ text: String) -> Bool {
    text.unicodeScalars.contains(where: CharacterSet.alphanumerics.contains)
  }

  private static func cleaned(_ line: String) -> String {
    guard !line.trimmingCharacters(in: .whitespaces).hasPrefix("```") else { return "" }
    var text = line.replacingOccurrences(
      of: #"^\s*(#+|[-*+]|\d+[.)])\s+"#,
      with: "",
      options: .regularExpression,
    )
    .replacingOccurrences(
      of: #"^\s*[*_]*name[*_]*\s*:[*_]*\s*"#,
      with: "",
      options: [.regularExpression, .caseInsensitive],
    )
    .trimmingCharacters(in: .whitespaces)
    // In any order: `"Billing export".` and `**"Billing export."**` alike.
    while let stripped = withoutFullStop(text) ?? withoutMarkdown(text) ?? withoutQuotes(text) {
      text = stripped
    }
    return text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }

  private static func withoutFullStop(_ text: String) -> String? {
    guard text.hasSuffix(".") else { return nil }
    return String(text.dropLast()).trimmingCharacters(in: .whitespaces)
  }

  /// Equal runs of one mark at both ends, so `**kwargs` and `__init__`
  /// inside a name stay.
  private static func withoutMarkdown(_ text: String) -> String? {
    guard let mark = text.first, markdownMarks.contains(mark) else { return nil }
    let leading = text.prefix { $0 == mark }.count
    let trailing = text.reversed().prefix { $0 == mark }.count
    guard leading == trailing, text.count > 2 * leading else { return nil }
    return String(text.dropFirst(leading).dropLast(trailing))
      .trimmingCharacters(in: .whitespaces)
  }

  /// Only a pair around the whole name, so `"Foo" and "Bar"` keeps its four.
  private static func withoutQuotes(_ text: String) -> String? {
    guard text.count >= 2, let first = text.first, let last = text.last,
      quotePairs[first] == last
    else { return nil }
    let inner = Array(text.dropFirst().dropLast())
    let closesEarly = inner.indices.contains { index in
      inner[index] == last && !isApostrophe(at: index, in: inner)
    }
    guard !closesEarly else { return nil }
    return String(inner).trimmingCharacters(in: .whitespaces)
  }

  /// `'` or `’` between two letters, as in `user's`, which closes no quote.
  private static func isApostrophe(at index: Int, in text: [Character]) -> Bool {
    index > 0 && index < text.count - 1 && text[index - 1].isLetter && text[index + 1].isLetter
  }

  private static func cut(_ name: String) -> String {
    guard name.count > maximumLength else { return name }
    let head = name.prefix(maximumLength)
    guard name.dropFirst(maximumLength).first != " " else { return String(head) }
    guard let lastSpace = head.lastIndex(of: " ") else { return String(head) }
    return String(head[..<lastSpace])
  }
}
