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

  /// Directories that change when worktrees do. Never the common `.git` once
  /// `worktrees/` exists; see Docs/design/worktrees.md.
  public static func directoriesToWatch(in common: URL) -> [URL] {
    let worktrees = common.appendingPathComponent("worktrees", isDirectory: true)
    guard FileManager.default.fileExists(atPath: worktrees.path) else { return [common] }
    let entries =
      (try? FileManager.default.contentsOfDirectory(at: worktrees, includingPropertiesForKeys: nil))
      ?? []
    return [worktrees] + entries.filter { FileManager.default.fileExists(atPath: $0.path) }
  }
}
