import Foundation

/// Parses `git log -g --format=%gs <branch>`: the message git wrote for each
/// of the branch's reflog entries, newest first, and answers whether any of
/// them records work made on the branch.
///
/// What tells a branch that landed from one that never began, which no
/// ancestry test can: `git worktree add -b` cuts a branch at the trunk's own
/// tip, and a `git pull` in a worktree cut before the trunk moved carries it
/// forward onto commits it was handed. Both leave a branch the trunk can
/// reach with nothing of its own, and counting the entries calls the second
/// one merged.
///
/// A deny list, because git writes only these shapes when a branch arrives at
/// someone else's commits and there is no listing the rest: a `commit:`, a
/// rebase's `(finish)`, a merge that made a commit and whatever a later git
/// adds all read as work, which is what counting entries already assumed of
/// every one of them.
///
/// Pure, tested against fixture text.
public enum ReflogWorkParser {
  public static func parse(_ output: String) -> Bool {
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let message = line.trimmingCharacters(in: .whitespaces)
      if !message.isEmpty, !isArrival(message) { return true }
    }
    return false
  }

  /// Read as git writes them, `<action>: <detail>`.
  ///
  /// `branch: Created from main`, `branch: Reset to origin/main`,
  /// `reset: moving to origin/main`, `clone: from <url>` and
  /// `fetch origin main:feat: storing head` are arrivals whatever follows.
  /// A `git merge` or `git pull` writes the command it was given as its
  /// action, so those are told apart by the detail: `Fast-forward` is an
  /// arrival, `Merge made by the 'ort' strategy.` is a commit of the
  /// branch's own. The detail is only read for those two, or a commit whose
  /// subject happened to be "Fast-forward" would be read as one.
  private static func isArrival(_ message: String) -> Bool {
    let parts = message.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let action = String(parts[0])
    let detail = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
    if action == "branch" || action == "reset" || action == "clone" { return true }
    if action.hasPrefix("fetch") { return true }
    guard action.hasPrefix("merge") || action.hasPrefix("pull") else { return false }
    return detail.caseInsensitiveCompare("Fast-forward") == .orderedSame
  }
}
