import Foundation

/// The extra arguments an agent is started with, as typed. Split into words
/// here rather than handed to a shell; see Docs/design/agents.md.
public enum AgentFlags {
  /// The line as an argument list, placeholders resolved. An unknown one is
  /// left as typed, so the mistake shows in the tab.
  public static func arguments(
    _ line: String, values: [AgentPlaceholder: String]
  ) -> [String] {
    split(line).map { expanded($0, values: values) }
  }

  /// The custom agent command, which runs as written: each placeholder reads
  /// a variable, so no value is ever shell text. See Docs/design/agents.md.
  public static func customLine(_ line: String, values: [AgentPlaceholder: String]) -> ShellLine {
    var tokens: [String: (variable: String, value: String)] = [:]
    for (placeholder, value) in values {
      tokens[placeholder.token] = (placeholder.variable, value)
    }
    return ShellLine(line, substituting: tokens)
  }

  /// One pass over what was typed. A token appearing in a value is text the
  /// user named something, not a placeholder; see Docs/design/agents.md.
  private static func expanded(_ text: String, values: [AgentPlaceholder: String]) -> String {
    var result = ""
    var rest = Substring(text)
    while let open = rest.range(of: "{{"),
      let close = rest.range(of: "}}", range: open.upperBound..<rest.endIndex)
    {
      result += rest[..<open.lowerBound]
      let name = String(rest[open.upperBound..<close.lowerBound])
      if let placeholder = AgentPlaceholder(rawValue: name), let value = values[placeholder] {
        result += value
      } else {
        result += rest[open.lowerBound..<close.upperBound]
      }
      rest = rest[close.upperBound...]
    }
    return result + rest
  }

  /// Words the way a shell reads them. A quote left open takes the rest of
  /// the line, there being nobody here to ask.
  static func split(_ line: String) -> [String] {
    var words: [String] = []
    var word = ""
    var hasWord = false
    var quote: Character?
    var escaping = false
    for character in line {
      if escaping {
        // Inside double quotes a backslash guards only these four, so
        // `"\d+"` keeps its backslash where `\d` outside quotes loses it.
        if quote == "\"", !#"\"$`"#.contains(character) { word.append("\\") }
        word.append(character)
        hasWord = true
        escaping = false
      } else if character == "\\", quote != "'" {
        // A word starts on the escaped character, not the backslash: a
        // trailing one would otherwise pass an empty final argument.
        escaping = true
      } else if let open = quote {
        if character == open { quote = nil } else { word.append(character) }
        hasWord = true
      } else if character == "'" || character == "\"" {
        // As with the escape, the word starts on what the quote carries,
        // never the opening mark: half a flag being typed passes nothing.
        quote = character
      } else if character.isWhitespace {
        if hasWord { words.append(word) }
        word = ""
        hasWord = false
      } else {
        word.append(character)
        hasWord = true
      }
    }
    if hasWord { words.append(word) }
    return words
  }
}
