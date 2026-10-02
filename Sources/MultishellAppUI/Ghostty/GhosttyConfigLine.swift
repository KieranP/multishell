import Foundation

/// How Ghostty reads one line of its config, the include walk and the
/// allow-list both splitting a file the same way.
enum GhosttyConfigLine {
  /// Swift reads `\r\n` as one character, so splitting on `\n` alone kept a
  /// CRLF file whole. Ghostty ends a line at either and nowhere else.
  static func lines(of text: String) -> [Substring] {
    text.split(omittingEmptySubsequences: false) { $0 == "\n" || $0 == "\r\n" }
  }

  /// What a line sets, before its first `=`, and empty for a line with none.
  static func key(of line: Substring) -> String {
    guard let separator = line.firstIndex(of: "=") else { return "" }
    return line[..<separator].trimmingCharacters(in: .whitespaces).lowercased()
  }
}
