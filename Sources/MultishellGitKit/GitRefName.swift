import Foundation
import MultishellCore

/// The repository itself, handed to a call that removes a worktree. The
/// only guard was a view three modules away; see docs/design/worktrees.md.
public struct NotAWorktree: LocalizedError {
  public let path: URL

  public init(path: URL) {
    self.path = path
  }

  public var errorDescription: String? {
    t("worktree.not-removable", path.path)
  }
}

/// A branch name git would refuse. Raised before the pre-create hook runs,
/// so a name that could never become a worktree runs nothing.
public struct InvalidBranchName: LocalizedError {
  public let branch: String

  public init(_ branch: String) {
    self.branch = branch
  }

  public var errorDescription: String? {
    t("branch-name.invalid", branch)
  }
}

/// Whether git would take a name as a branch. `git check-ref-format
/// --branch` answers this, but the sheet asks on every keystroke and a
/// process per keystroke is not worth it, so the rules are here.
///
/// The rules are `git-check-ref-format(1)`'s, less the ones about slashes
/// that only apply to a full refname.
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
