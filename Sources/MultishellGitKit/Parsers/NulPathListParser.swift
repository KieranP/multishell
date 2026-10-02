/// Parses a git path list written with `-z`, where a newline is part of a
/// path. Only the paths within `limit` become strings; see worktrees.md.
enum NulPathListParser {
  static func parse(_ output: String, limit: Int = .max) -> [String] {
    output.split(separator: "\0", omittingEmptySubsequences: true)
      .prefix(limit).map(String.init)
  }
}
