import Foundation

/// Parses `git branch --merged <base> --format=%(refname:lstrip=2)`: one
/// branch name per line, with no marker for the checked-out ones.
enum MergedBranchParser {
  static func parse(_ output: String) -> Set<String> {
    var branches: Set<String> = []
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let name = line.trimmingCharacters(in: .whitespaces)
      guard !name.isEmpty else { continue }
      branches.insert(name)
    }
    return branches
  }
}
