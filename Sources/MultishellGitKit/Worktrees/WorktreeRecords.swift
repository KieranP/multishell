import Foundation

/// The files under the common `.git` deciding what `git worktree list` says.
/// Comparing them across a tick tells a change from an index write.
public struct WorktreeRecords: Hashable, Sendable {
  let files: [String: String]

  public static func read(in common: URL) -> Self {
    var files: [String: String] = [:]
    func readFile(_ relative: String) {
      let url = common.appendingPathComponent(relative)
      if let data = try? Data(contentsOf: url) {
        files[relative] = String(decoding: data, as: UTF8.self)
      }
    }

    readFile("HEAD")
    let worktrees = worktreesDirectory(in: common)
    let entries =
      (try? FileManager.default.contentsOfDirectory(atPath: worktrees.path))?.sorted() ?? []
    for entry in entries {
      for name in ["HEAD", "gitdir", "locked"] {
        readFile("worktrees/\(entry)/\(name)")
      }
    }
    return Self(files: files)
  }

  /// `<common>/worktrees`, which holds one record directory per linked checkout.
  static func worktreesDirectory(in common: URL) -> URL {
    common.appendingPathComponent("worktrees", isDirectory: true)
  }
}
