/// Parses `git diff --name-only -z`, NUL separated: a path may hold a
/// newline, and git quotes one that does.
enum ChangedPathParser {
  static func parse(_ output: String) -> Set<String> {
    Set(output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init))
  }
}
