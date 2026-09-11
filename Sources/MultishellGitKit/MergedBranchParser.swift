import Foundation

/// Parses `git branch --merged <base>`. Only `* ` and `+ ` are stripped, a
/// ref name holding no space; `(wip)` is a branch git will make.
public enum MergedBranchParser {
  public static func parse(_ output: String) -> Set<String> {
    var branches: Set<String> = []
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      var name = line.trimmingCharacters(in: .whitespaces)
      // `* main` is the checked-out branch, `+ feat` one checked out in
      // another worktree, which is every branch this app cares about.
      if name.hasPrefix("* ") || name.hasPrefix("+ ") { name = String(name.dropFirst(2)) }
      name = name.trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty else { continue }
      branches.insert(name)
    }
    return branches
  }
}
