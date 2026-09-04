import Foundation
import MultishellCore

/// Parses `git status --porcelain=v1 --branch`.
///
/// The first line is `## <branch>...<upstream> [ahead N, behind M]`; every
/// other line is `XY <path>`, where X is the index state and Y the working
/// tree state. Pure, so the format is tested against fixture text.
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
  /// `## No commits yet on main`.
  private static func parseBranchLine(_ line: Substring, into status: inout WorktreeStatus) {
    var head = line.dropFirst(3)
    if let bracket = head.firstIndex(of: "[") { head = head[..<bracket] }
    let name = head.trimmingCharacters(in: .whitespaces)
    if name.hasPrefix("HEAD (") {
      status.branch = nil
    } else if let range = name.range(of: "No commits yet on ")
      ?? name.range(of: "Initial commit on ")
    {
      status.branch = String(name[range.upperBound...])
    } else if let dots = name.range(of: "...") {
      status.branch = String(name[..<dots.lowerBound])
    } else {
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
}
