import Foundation

/// Parses `git branch --merged <base> --format=%(refname:short)`: the
/// branches whose tip the base can reach, so merged by a merge commit or a
/// fast-forward.
///
/// `--format` is asked for so there is nothing to strip, but the decoration
/// a bare `git branch` prints is stripped anyway, for a version that ignores
/// the format. Only the two markers a ref name could never begin with: a ref
/// name may hold no space, so `* ` and `+ ` are always decoration and never
/// the start of a branch.
///
/// Nothing else is dropped, `(HEAD detached at abc1234)` included. A
/// parenthesis is legal in a branch name — `(wip)` is a branch git will
/// make — so a guard against that line would cost a real branch its badge,
/// while the line itself costs nothing: what lands here is only ever looked
/// up by a name a worktree actually has. Pure, tested against fixture text.
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
