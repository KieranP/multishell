/// Parses `git ls-files --others -z`, one NUL-terminated path a file. Only
/// the paths that will be read become strings; see worktrees.md.
enum UntrackedPathParser {
  static func parse(_ output: String, limit: Int) -> [String] {
    output.split(separator: "\0", omittingEmptySubsequences: true)
      .prefix(limit).map(String.init)
  }
}
