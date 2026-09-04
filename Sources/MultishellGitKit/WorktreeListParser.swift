import Foundation
import MultishellCore

/// Parses `git worktree list --porcelain`.
///
/// Kept free of any process or filesystem access so the format is testable
/// against fixture text alone.
public enum WorktreeListParser {
  /// Records are blank-line separated. Each begins with `worktree <path>`,
  /// then `HEAD <sha>` and either `branch <ref>` or `detached`, plus
  /// optional `bare`, `locked` and `prunable` markers.
  public static func parse(_ porcelain: String, projectID: Project.ID) -> [Worktree] {
    var worktrees: [Worktree] = []
    var fields: [String: String] = [:]

    func flush() {
      defer { fields = [:] }
      guard let path = fields["worktree"] else { return }
      worktrees.append(
        Worktree(
          path: URL(fileURLWithPath: path),
          projectID: projectID,
          head: fields["HEAD"] ?? "",
          branch: fields["branch"].map(shortBranchName),
          isPrimary: worktrees.isEmpty,
          isLocked: fields["locked"] != nil
        )
      )
    }

    // Split on `isNewline`, not on "\n": git under Windows emits CRLF, and
    // Swift treats \r\n as one grapheme, so a Character separator of "\n"
    // matches nothing and the whole output parses as a single line.
    for line in porcelain.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline) {
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
