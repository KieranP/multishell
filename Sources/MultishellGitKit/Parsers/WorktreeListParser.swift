import Foundation
import MultishellCore

/// Parses `git worktree list --porcelain -z`, free of any process or
/// filesystem access so the format is testable against fixture text alone.
enum WorktreeListParser {
  /// Records of `worktree <path>`, `HEAD <sha>` and `branch <ref>` or `detached`,
  /// split on NUL for `-z` or a newline for an older git's form; see worktrees.md.
  static func parse(
    _ porcelain: String, projectID: Project.ID, separator: Character = "\0"
  ) -> [Worktree] {
    var worktrees: [Worktree] = []
    var fields: [String: String] = [:]

    func flush() {
      defer { fields = [:] }
      // `URL(filePath: "")` is the current directory, not nothing.
      guard let path = fields["worktree"], !path.isEmpty else { return }
      worktrees.append(
        Worktree(
          path: URL(filePath: path, directoryHint: .isDirectory),
          projectID: projectID,
          head: fields["HEAD"] ?? "",
          branch: fields["branch"].map(BranchRef.shortLocalName),
          isPrimary: worktrees.isEmpty,
          isLocked: fields["locked"] != nil,
          isInitializing: fields["locked"] == "initializing",
          isBare: fields["bare"] != nil
        )
      )
    }

    // An empty field is the blank line the plain form had: end of record.
    for line in porcelain.split(separator: separator, omittingEmptySubsequences: false) {
      if line.isEmpty {
        flush()
        continue
      }
      let (key, value) = split(String(line))
      fields[key] = value
    }
    flush()

    return worktrees
  }

  private static func split(_ line: String) -> (key: String, value: String) {
    guard let space = line.firstIndex(of: " ") else { return (line, "") }
    return (String(line[line.startIndex..<space]), String(line[line.index(after: space)...]))
  }
}
