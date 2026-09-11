import Foundation

/// Parses `git log -g --format=%gs <branch>`: whether any entry records work
/// of the branch's own. A deny list; see docs/design/merged-branch.md.
public enum ReflogWorkParser {
  public static func parse(_ output: String) -> Bool {
    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      let message = line.trimmingCharacters(in: .whitespaces)
      if !message.isEmpty, !isArrival(message) { return true }
    }
    return false
  }

  /// Read as git writes them, `<action>: <detail>`. The detail is read only
  /// for merge and pull, or a commit subject could be mistaken for one.
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
