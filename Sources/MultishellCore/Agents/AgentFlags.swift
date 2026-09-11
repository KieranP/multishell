import Foundation

/// What a flag line may stand in for, written `{{branch}}`.
///
/// The whole list, and the only place one is spelled: the settings rows name
/// an example rather than all five, so what a case means is written for the
/// reader here and for the user in the documentation.
public enum AgentPlaceholder: String, CaseIterable, Sendable {
  /// The branch, or the short SHA when detached.
  case branch
  /// What the sidebar calls the worktree: the user's name for it, else its
  /// branch.
  case worktree
  /// The worktree's directory.
  case worktreePath = "worktree_path"
  /// The repository's folder name.
  case project
  /// The repository root.
  case projectPath = "project_path"

  public var token: String { "{{\(rawValue)}}" }

  /// `name` is what the sidebar shows, `Workspace.displayName(of:)`, which
  /// the worktree record cannot answer on its own.
  public static func values(
    project: Project, worktree: Worktree, name: String
  ) -> [AgentPlaceholder: String] {
    var values: [AgentPlaceholder: String] = [:]
    for placeholder in allCases {
      values[placeholder] =
        switch placeholder {
        case .branch: worktree.branch ?? worktree.name
        case .worktree: name
        case .worktreePath: worktree.path.path
        case .project: project.name
        case .projectPath: project.path.path
        }
    }
    return values
  }
}

/// The extra arguments an agent is started with, as the user typed them.
///
/// Split into words here rather than handed to the shell as text, so a
/// branch with a space in it stays one argument: the words are quoted again
/// by `AgentLaunch` on the way to the command line.
public enum AgentFlags {
  /// The line as an argument list, placeholders resolved. A placeholder the
  /// list above does not name is left as typed, where the tab's scrollback
  /// shows it rather than an argument quietly going missing.
  public static func arguments(
    _ line: String, values: [AgentPlaceholder: String]
  ) -> [String] {
    split(line).map { expanded($0, values: values, quoting: false) }
  }

  /// The same for a line that stays text: the custom agent command, which
  /// runs as written, so each value is quoted where it lands.
  public static func expand(_ line: String, values: [AgentPlaceholder: String]) -> String {
    expanded(line, values: values, quoting: true)
  }

  private static func expanded(
    _ text: String, values: [AgentPlaceholder: String], quoting: Bool
  ) -> String {
    var expanded = text
    // `allCases` rather than the dictionary, whose order is arbitrary: two
    // runs must expand the same line the same way.
    for placeholder in AgentPlaceholder.allCases {
      guard let value = values[placeholder] else { continue }
      expanded = expanded.replacingOccurrences(
        of: placeholder.token, with: quoting ? ShellQuoting.quote(value) : value)
    }
    return expanded
  }

  /// Words the way a shell reads them: whitespace separates, `'` and `"`
  /// group, `\` passes the next character through. A quote left open takes
  /// the rest of the line, which is what a shell would report an error for
  /// and nothing here can ask about.
  static func split(_ line: String) -> [String] {
    var words: [String] = []
    var word = ""
    var hasWord = false
    var quote: Character?
    var escaping = false
    for character in line {
      if escaping {
        // Inside double quotes a backslash guards only these four and is
        // otherwise a character of its own, so `"\d+"` keeps its backslash
        // where `\d` outside quotes loses it. A regex or a Windows path
        // typed into the field is the case that notices.
        if quote == "\"", !#"\"$`"#.contains(character) { word.append("\\") }
        word.append(character)
        hasWord = true
        escaping = false
      } else if character == "\\", quote != "'" {
        // A word starts on the escaped character, not on the backslash: a
        // line ending in one is an escape nothing completed, and counting
        // it would end the line with an empty argument the agent has to
        // make sense of.
        escaping = true
      } else if let open = quote {
        if character == open { quote = nil } else { word.append(character) }
        hasWord = true
      } else if character == "'" || character == "\"" {
        // As with the escape above, the word starts on what the quote
        // carries or on its closing mark, never on the opening one: a line
        // ending in a quote nobody closed is half a flag being typed, and
        // counting it would pass the agent an empty argument.
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
