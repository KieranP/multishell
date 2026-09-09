import Foundation

/// Parses `git cherry <base> <branch>`: one line per commit on the branch,
/// `-` where the base already has an equivalent patch and `+` where it does
/// not. Every line a `-` means the branch has landed by a rebase-merge or a
/// run of cherry-picks, which no ancestry test can see.
///
/// At least one `-` is required, so no output at all is not an answer.
/// `git cherry` skips merge commits, and it is only asked about branches the
/// base cannot reach, which have at least one commit of their own: a branch
/// that prints nothing is one whose every commit ahead is a merge, and a
/// merge of the trunk into a worktree is not that worktree landing.
/// Pure, tested against fixture text.
public enum PatchEquivalenceParser {
  public static func parse(_ output: String) -> Bool {
    var landed = false
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      guard !trimmed.isEmpty else { continue }
      if trimmed.hasPrefix("+") { return false }
      if trimmed.hasPrefix("-") { landed = true }
    }
    return landed
  }
}
