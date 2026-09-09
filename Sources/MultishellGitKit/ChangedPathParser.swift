import Foundation

/// Parses `git diff --name-only -z`: the paths a diff touched, NUL separated.
///
/// `-z` rather than lines, because a path may hold a newline and git quotes
/// one that does; the quoting is what a line parser would have to undo.
/// Pure, tested against fixture text.
public enum ChangedPathParser {
  public static func parse(_ output: String) -> Set<String> {
    Set(output.split(separator: "\0", omittingEmptySubsequences: true).map(String.init))
  }
}
