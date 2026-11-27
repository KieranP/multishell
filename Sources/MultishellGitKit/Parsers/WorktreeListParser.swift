import Foundation
import MultishellCore

/// Parses `git worktree list --porcelain -z`, free of any process or
/// filesystem access so the format is testable against fixture text alone.
enum WorktreeListParser {
  /// Records of `worktree <path>`, `HEAD <sha>` and `branch <ref>` or `detached`,
  /// each field NUL-terminated; see worktrees/watching-and-status-reads.md.
  static func parse(_ porcelain: String, projectID: Project.ID) -> [Worktree] {
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
          branch: fields["branch"].map(RefName.shortLocal),
          isPrimary: worktrees.isEmpty,
          isLocked: fields["locked"] != nil,
          isInitializing: fields["locked"] == "initializing",
          isBare: fields["bare"] != nil,
        )
      )
    }

    // An empty field ends a record.
    for line in porcelain.split(separator: "\0", omittingEmptySubsequences: false) {
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
