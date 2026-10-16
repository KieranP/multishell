import Foundation

/// Which repository a worktree's file belongs to: the worktree's, or a
/// submodule or nested repository git in the worktree will not diff into.
struct RepositoryLocation: Equatable, Sendable {
  let directory: URL
  /// Relative to `directory`.
  let path: String

  /// The innermost folder above the file holding a `.git`, the worktree's own
  /// top left out. Blocking: callers run it through `runOnDispatch`.
  static func innermost(holding path: String, in worktree: URL) -> Self {
    let parts = path.split(separator: "/").map(String.init)
    for depth in stride(from: parts.count - 1, to: 0, by: -1) {
      let folder = worktree.appending(path: parts.prefix(depth).joined(separator: "/"))
      if FileManager.default.fileExists(atPath: folder.appending(path: ".git").path) {
        return Self(directory: folder, path: parts.dropFirst(depth).joined(separator: "/"))
      }
    }
    return Self(directory: worktree, path: path)
  }
}
