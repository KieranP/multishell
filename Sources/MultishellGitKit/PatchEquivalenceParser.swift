import Foundation

/// Parses `git cherry <base> <branch>`: one line per commit on the branch,
/// `-` where the base already has an equivalent patch and `+` where it does
/// not. Every line a `-` means the branch has landed by a rebase-merge or a
/// run of cherry-picks, which no ancestry test can see.
///
/// No output at all means no commit is missing from the base, which is the
/// same answer. Pure, tested against fixture text.
public enum PatchEquivalenceParser {
  public static func parse(_ output: String) -> Bool {
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      if trimmed.hasPrefix("+") { return false }
    }
    return true
  }
}
