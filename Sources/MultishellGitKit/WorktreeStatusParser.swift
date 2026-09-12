import Foundation
import MultishellCore

/// Parses `git status --porcelain=v1 --branch`: a `## <branch>...` line,
/// then `XY <path>` for the index state and the working tree state.
public enum WorktreeStatusParser {
  public static func parse(_ output: String) -> WorktreeStatus {
    var status = WorktreeStatus()

    for line in output.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline) {
      if line.hasPrefix("## ") {
        parseBranchLine(line, into: &status)
        continue
      }
      guard line.count >= 2 else { continue }
      let x = line[line.startIndex]
      let y = line[line.index(after: line.startIndex)]

      switch (x, y) {
      case ("!", "!"):
        continue
      case ("?", "?"):
        status.untracked += 1
      case ("U", _), (_, "U"), ("A", "A"), ("D", "D"):
        status.conflicted += 1
      default:
        if x != " " { status.staged += 1 }
        if y != " " { status.unstaged += 1 }
      }
      status.changedFiles += 1
    }
    return status
  }

  /// `## main...origin/main [ahead 1]`, `## main`, `## HEAD (no branch)`,
  /// `## No commits yet on main`, `## No commits yet on main...origin/main`.
  private static func parseBranchLine(_ line: Substring, into status: inout WorktreeStatus) {
    var head = line.dropFirst(3)
    if let bracket = head.firstIndex(of: "[") { head = head[..<bracket] }
    var name = head.trimmingCharacters(in: .whitespaces)
    if name.hasPrefix("HEAD (") {
      status.branch = nil
    } else {
      // The upstream goes first: a clone of an empty repository has one from
      // clone time, and reads `No commits yet on main...origin/main`.
      if let dots = name.range(of: "...") { name = String(name[..<dots.lowerBound]) }
      if let prefix = unbornPrefixes.first(where: name.hasPrefix) {
        name = String(name.dropFirst(prefix.count))
      }
      status.branch = name.isEmpty ? nil : name
    }

    guard let open = line.lastIndex(of: "["), let close = line.lastIndex(of: "]"), open < close
    else { return }
    for part in line[line.index(after: open)..<close].split(separator: ",") {
      let words = part.trimmingCharacters(in: .whitespaces).split(separator: " ")
      guard words.count == 2, let count = Int(words[1]) else { continue }
      switch words[0] {
      case "ahead": status.ahead = count
      case "behind": status.behind = count
      default: break
      }
    }
  }

  /// How git says a branch has no commits yet; the second is its wording
  /// before 2.19. English in `--porcelain` whatever the locale, checked on 2.55.
  private static let unbornPrefixes = ["No commits yet on ", "Initial commit on "]
}
