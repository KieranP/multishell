import Foundation

/// One spelling sh, zsh, bash, dash, tcsh and fish read alike, typed at a
/// prompt or run as a script; see Docs/design/terminals.md.
public enum AnyShellQuoting {
  /// Characters no shell above reads specially anywhere in a word.
  private static let bare = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))

  /// Single quotes, with a quote, a backslash and a `!` each outside them:
  /// fish escapes a backslash inside quotes, and csh expands a `!` there.
  public static func quote(_ word: String) -> String {
    if !word.isEmpty, word.unicodeScalars.allSatisfy(bare.contains) { return word }
    var quoted = "'"
    for character in word {
      switch character {
      case "'": quoted += #"'\''"#
      case "\\": quoted += #"'\\'"#
      case "!": quoted += #"'\!'"#
      default: quoted.append(character)
      }
    }
    return quoted + "'"
  }
}
