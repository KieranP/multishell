import Foundation

/// Whether git would take a name as a branch: `git-check-ref-format(1)`'s
/// rules in Swift, less the full-refname ones about slashes; see worktrees.md.
public enum GitRefName {
  private static let forbidden: Set<Character> = [
    " ", "~", "^", ":", "?", "*", "[", "\\",
  ]

  public static func isValidBranch(_ name: String) -> Bool {
    let name = name.trimmingCharacters(in: .whitespaces)
    // `@` alone is barred for a whole refname, not for a branch: git takes
    // it as `refs/heads/@`. `HEAD` it reads as the current branch instead.
    guard !name.isEmpty, name != "HEAD", !name.hasPrefix("-"), !name.hasSuffix(".") else {
      return false
    }
    guard !name.hasPrefix("/"), !name.hasSuffix("/"), !name.hasSuffix(".lock") else {
      return false
    }
    guard !name.contains(".."), !name.contains("@{"), !name.contains("//") else { return false }
    for component in name.split(separator: "/", omittingEmptySubsequences: false) {
      guard !component.isEmpty, !component.hasPrefix("."), !component.hasSuffix(".lock")
      else { return false }
    }
    return !name.contains { character in
      forbidden.contains(character) || character.isASCIIControl || character == "\u{7f}"
    }
  }
}

extension Character {
  fileprivate var isASCIIControl: Bool {
    guard let ascii = asciiValue else { return false }
    return ascii < 0x20
  }
}
