import Foundation

/// The files under the common `.git` deciding what `git worktree list` says.
/// Comparing them across a tick tells a change from an index write.
public struct WorktreeRecords: Hashable, Sendable {
  public let files: [String: String]

  public static func read(commonDirectory: URL) -> WorktreeRecords {
    var files: [String: String] = [:]
    func record(_ relative: String) {
      let url = commonDirectory.appendingPathComponent(relative)
      if let data = try? Data(contentsOf: url) {
        files[relative] = String(decoding: data, as: UTF8.self)
      }
    }

    record("HEAD")
    let worktrees = commonDirectory.appendingPathComponent("worktrees", isDirectory: true)
    let entries =
      (try? FileManager.default.contentsOfDirectory(atPath: worktrees.path))?.sorted() ?? []
    for entry in entries {
      for name in ["HEAD", "gitdir", "locked"] {
        record("worktrees/\(entry)/\(name)")
      }
    }
    return WorktreeRecords(files: files)
  }
}
