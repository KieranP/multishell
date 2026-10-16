/// Parses a git path list written with `-z`, where a newline is part of a
/// path. Only the paths within `limit` become strings; see worktrees.md.
enum NulPathListParser {
  static func parse(_ output: String, limit: Int = .max) -> [String] {
    output.split(separator: "\0", omittingEmptySubsequences: true)
      .prefix(limit).map(String.init)
  }

  /// Every path in the list, counted without making a string of any.
  static func count(_ output: String) -> Int {
    var count = 0
    var previous: UInt8 = 0
    for byte in output.utf8 {
      if byte == 0, previous != 0 { count += 1 }
      previous = byte
    }
    return previous == 0 ? count : count + 1
  }
}
