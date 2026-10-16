import Foundation
import MultishellAppCore

/// How Ghostty reads one line of its config, the include walk and the
/// allow-list both splitting a file the same way.
enum GhosttyConfigLine {
  /// Ghostty ends a line at `\n` or `\r\n` and nowhere else.
  static func lines(of text: String) -> [Substring] { text.lines() }

  /// What a line sets, before its first `=`, and empty for a line with none.
  static func key(of line: Substring) -> String {
    guard let separator = line.firstIndex(of: "=") else { return "" }
    return line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
  }
}
