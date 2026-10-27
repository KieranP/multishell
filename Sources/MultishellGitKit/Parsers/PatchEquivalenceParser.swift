import Foundation

/// Parses `git cherry <base> <branch>`: every line a `-` means a rebase-merge
/// landed it, and no output is not an answer. See merged-branch.md.
enum PatchEquivalenceParser {
  static func parse(_ output: String) -> Bool {
    var landed = false
    for line in lines(of: output) {
      if line.hasPrefix("+") { return false }
      if line.hasPrefix("-") { landed = true }
    }
    return landed
  }

  /// The `+` commits: those whose change the base has no match for.
  static func unmatchedCommits(_ output: String) -> Set<String> {
    Set(
      lines(of: output).filter { $0.hasPrefix("+") }
        .map { $0.dropFirst().trimmingCharacters(in: .whitespaces) }
    )
  }

  private static func lines(of output: String) -> [String] {
    output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { !$0.isEmpty }
  }
}
