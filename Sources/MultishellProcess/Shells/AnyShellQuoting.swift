import Foundation

/// One spelling sh, zsh, bash, dash, tcsh and fish read alike, typed at a
/// prompt or run as a script; see Docs/design/terminals/paste-and-drop.md.
public enum AnyShellQuoting {
  /// Characters no shell above reads specially anywhere in a word.
  private static let bare = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_./"))

  public static func commandLine(_ words: [String]) -> String {
    words.map(quote).joined(separator: " ")
  }

  /// Single quotes, with a quote, a backslash and a `!` each outside them:
  /// fish escapes a backslash inside quotes, and csh expands a `!` there.
  public static func quote(_ word: String) -> String {
    if !word.isEmpty, word.unicodeScalars.allSatisfy(bare.contains) { return word }
    var quoted = "'"
    // By scalar: a combining mark after a quote joins it into one Character,
    // which a Character match would leave unescaped, closing the quote early.
    for scalar in word.unicodeScalars {
      switch scalar {
      case "'": quoted += #"'\''"#
      case "\\": quoted += #"'\\'"#
      case "!": quoted += #"'\!'"#
      default: quoted.unicodeScalars.append(scalar)
      }
    }
    return quoted + "'"
  }
}
