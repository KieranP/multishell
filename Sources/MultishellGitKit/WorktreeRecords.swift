import Foundation

/// The files under the common `.git` that decide what `git worktree list`
/// reports: the main `HEAD`, and each linked worktree's `HEAD`, `gitdir` and
/// `locked`. Read directly, no process.
///
/// The watcher covers the directories these live in, but so does every
/// linked worktree's `index`, which `git status` rewrites. Comparing records
/// before and after a tick tells a real change from an index write without
/// spawning git.
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
