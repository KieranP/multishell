import Foundation
import MultishellCore

/// Parses `git worktree list --porcelain -z`, free of any process or
/// filesystem access so the format is testable against fixture text alone.
public enum WorktreeListParser {
  /// NUL-terminated records of `worktree <path>`, `HEAD <sha>` and either
  /// `branch <ref>` or `detached`; see docs/design/worktrees.md for `-z`.
  public static func parse(_ porcelain: String, projectID: Project.ID) -> [Worktree] {
    var worktrees: [Worktree] = []
    var fields: [String: String] = [:]

    func flush() {
      defer { fields = [:] }
      // `URL(fileURLWithPath: "")` is the current directory, not nothing.
      guard let path = fields["worktree"], !path.isEmpty else { return }
      worktrees.append(
        Worktree(
          path: URL(fileURLWithPath: path),
          projectID: projectID,
          head: fields["HEAD"] ?? "",
          branch: fields["branch"].map(shortBranchName),
          isPrimary: worktrees.isEmpty,
          isLocked: fields["locked"] != nil,
          isBare: fields["bare"] != nil
        )
      )
    }

    // An empty field is the blank line the plain form had: end of record.
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

  private static func shortBranchName(_ ref: String) -> String {
    ref.hasPrefix("refs/heads/") ? String(ref.dropFirst("refs/heads/".count)) : ref
  }
}
