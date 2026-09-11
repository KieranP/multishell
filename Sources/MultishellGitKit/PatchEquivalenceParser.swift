import Foundation

/// Parses `git cherry <base> <branch>`: every line a `-` means a rebase-merge
/// landed it, and no output is not an answer. See merged-branch.md.
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
