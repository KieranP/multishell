import Foundation

/// Parses `git status --porcelain=v1 -z --branch`: `## <branch>...`, then
/// `XY <path>`, the path unquoted and able to hold a newline.
enum WorktreeStatusParser {
  /// How git says a branch has no commits yet; the second is its wording
  /// before 2.19. English in `--porcelain` whatever the locale, checked on 2.55.
  private static let unbornPrefixes = ["No commits yet on ", "Initial commit on "]

  static func parse(_ output: String) -> (status: WorktreeStatus, entries: [StatusEntry]) {
    var status = WorktreeStatus()
    var entries: [StatusEntry] = []

    for record in output.split(separator: "\0", omittingEmptySubsequences: true) {
      if record.hasPrefix("## ") {
        parseBranchLine(record, into: &status)
        continue
      }
      guard let entry = entry(from: record) else { continue }
      if entry.isUntracked {
        status.untracked += 1
      } else if entry.isUnmerged {
        status.conflicted += 1
      } else {
        if entry.indexState != " " { status.staged += 1 }
        if entry.workTreeState != " " { status.unstaged += 1 }
      }
      status.changedFiles += 1
      entries.append(entry)
    }
    return (status, entries)
  }

  /// Sliced by byte: a path starting with a combining mark joins the space
  /// before it into one `Character`.
  private static func entry(from record: Substring) -> StatusEntry? {
    let bytes = record.utf8
    guard bytes.count > 3, bytes[bytes.index(bytes.startIndex, offsetBy: 2)] == UInt8(ascii: " ")
    else { return nil }
    let states = Array(bytes.prefix(2))
    guard states.allSatisfy({ $0 < 0x80 }), states != Array("!!".utf8) else { return nil }
    return StatusEntry(
      indexState: Character(UnicodeScalar(states[0])),
      workTreeState: Character(UnicodeScalar(states[1])),
      path: String(Substring(bytes.dropFirst(3))),
    )
  }

  /// `## main...origin/main [ahead 1]`, `## main`, `## HEAD (no branch)`,
  /// `## No commits yet on main`, `## No commits yet on main...origin/main`.
  private static func parseBranchLine(_ line: Substring, into status: inout WorktreeStatus) {
    var header = line.dropFirst(3)
    if let bracket = header.firstIndex(of: "[") { header = header[..<bracket] }
    var name = header.trimmingCharacters(in: .whitespaces)
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
}
