import Foundation

extension NewWorktreeDraft {
  private static func dashingUnusualCharacters(in text: String) -> String {
    var result = ""
    var pendingRun = ""
    var pendingRunHasUnusualCharacter = false
    func flushPendingRun() {
      if !pendingRunHasUnusualCharacter {
        result += pendingRun
      } else if !result.isEmpty {
        result += "-"
      }
      pendingRun = ""
      pendingRunHasUnusualCharacter = false
    }
    for character in text {
      if character == "-" || !isUsualInBranchNames(character) {
        pendingRun.append(character)
        pendingRunHasUnusualCharacter = pendingRunHasUnusualCharacter || character != "-"
      } else {
        flushPendingRun()
        result.append(character)
      }
    }
    // Trailing spaces are left for `trimmedBranch` to drop, as a paste often
    // brings them; the next word typed turns them into its dash.
    if !result.isEmpty, pendingRun.unicodeScalars.allSatisfy(CharacterSet.whitespaces.contains) {
      return result + pendingRun
    }
    flushPendingRun()
    return result
  }

  private static func isUsualInBranchNames(_ character: Character) -> Bool {
    character.isLetter || character.isNumber || "./_".contains(character)
  }

  /// What the branch field hands in, pasted or typed. A run of characters
  /// unusual in a branch name becomes one `-`; see worktrees.md.
  public mutating func typeBranch(_ text: String) {
    branch = Self.dashingUnusualCharacters(in: text)
  }
}
