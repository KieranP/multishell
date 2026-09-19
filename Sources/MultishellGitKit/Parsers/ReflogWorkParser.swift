import Foundation

/// Parses `git log -g --format=%H %gs <branch>`: whether any entry records
/// work of the branch's own. A deny list; see Docs/design/merged-branch.md.
enum ReflogWorkParser {
  static func parse(_ output: String) -> Bool {
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let entry = line.trimmingCharacters(in: .whitespaces)
      let parts = entry.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
      let newValue = String(parts[0])
      let message = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
      if !message.isEmpty, !isArrival(message, restingAt: newValue) { return true }
    }
    return false
  }

  /// Read as git writes them, `<action>: <detail>`. The detail is read only
  /// for merge, pull and a rebase's finish, or a commit subject could pose as one.
  private static func isArrival(_ message: String, restingAt newValue: String) -> Bool {
    let parts = message.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    let action = String(parts[0])
    let detail = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""
    if action == "branch" || action == "reset" || action == "clone" { return true }
    if action.hasPrefix("fetch") { return true }
    if action.hasSuffix("(finish)") || action.hasSuffix(" finished"),
      rebaseReplayedNothing(detail, restingAt: newValue)
    {
      return true
    }
    guard action.hasPrefix("merge") || action.hasPrefix("pull") else { return false }
    return detail.caseInsensitiveCompare("Fast-forward") == .orderedSame
  }

  /// `<ref> onto <sha>`: a branch that came to rest on the commit it was
  /// rebased onto had nothing to replay. Past it, it had commits of its own.
  private static func rebaseReplayedNothing(_ detail: String, restingAt newValue: String) -> Bool {
    let words = detail.split(separator: " ")
    guard words.count >= 2, words[words.count - 2] == "onto" else { return false }
    let target = words[words.count - 1]
    guard !target.isEmpty, target.allSatisfy(\.isHexDigit) else { return false }
    return newValue == target
  }
}
