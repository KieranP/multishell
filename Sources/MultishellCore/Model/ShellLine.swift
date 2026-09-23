import Foundation

/// A line the user wrote for their shell, with each value it names handed
/// over in the environment rather than written into it; see agents.md.
public struct ShellLine: Hashable, Sendable {
  /// Trimmed, so an empty line is one with nothing to run.
  public let text: String
  let environment: [String: String]

  init(text: String, environment: [String: String] = [:]) {
    self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
    self.environment = environment
  }

  /// `line` with each token read from a variable holding its value. The read
  /// is quoted for where the token sits, so it is one word inside any quotes.
  init(_ line: String, substituting tokens: [String: (variable: String, value: String)]) {
    var text = ""
    var environment: [String: String] = [:]
    var quote: Character?
    var escaping = false
    var rest = Substring(line)
    while let character = rest.first {
      if !escaping, let token = tokens.first(where: { rest.hasPrefix($0.key) }) {
        text += Self.reading(token.value.variable, inside: quote)
        environment[token.value.variable] = token.value.value
        rest = rest.dropFirst(token.key.count)
        continue
      }
      if escaping {
        escaping = false
      } else if character == "\\", quote != "'" {
        escaping = true
      } else if let open = quote {
        if character == open { quote = nil }
      } else if character == "'" || character == "\"" {
        quote = character
      }
      text.append(character)
      rest = rest.dropFirst()
    }
    self.init(text: text, environment: environment)
  }

  /// Closes the user's quote, reads the variable double-quoted, and reopens
  /// it: one spelling that sh, zsh, bash, dash and tcsh read as one word.
  private static func reading(_ variable: String, inside quote: Character?) -> String {
    let read = "\"$\(variable)\""
    guard let quote else { return read }
    return "\(quote)\(read)\(quote)"
  }

  /// The command that runs `command` with the environment set, through
  /// `env` so no shell parses a value on the way.
  public func prefixing(_ command: [String]) -> [String] {
    guard !environment.isEmpty else { return command }
    let assignments = environment.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }
    return ["/usr/bin/env"] + assignments + command
  }
}
