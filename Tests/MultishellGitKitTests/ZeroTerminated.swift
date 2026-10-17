import Foundation

/// A fixture written a record per line, as git prints it with `-z`: the
/// same with NUL where each newline was.
func zeroTerminated(_ text: String) -> String {
  text.replacingOccurrences(of: "\n", with: "\u{0}")
}
