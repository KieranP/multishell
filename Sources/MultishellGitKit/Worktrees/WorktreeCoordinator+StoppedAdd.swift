import Foundation
import MultishellCore

extension WorktreeCoordinator {
  /// A stopped add leaves its new branch and its directories, and the worktree
  /// where git had finished, so the same name could not be tried again.
  func undoStoppedAdd(
    _ path: URL, worktreeIsNew: Bool, branch: String?, through highestNewDirectory: URL?,
    in project: Project
  ) async {
    if worktreeIsNew { await git.removeUnchanged(path, in: project) }
    if let branch { await git.deleteBranchIfUnlisted(branch, in: project) }
    if let highestNewDirectory {
      await offMain { Self.removeEmptyDirectories(from: path, through: highestNewDirectory) }
    }
  }

  /// The topmost directory on the way to `path` that is not there yet.
  static func highestMissingAncestor(of path: URL) -> URL? {
    let (existing, unmade) = path.splitAtDeepestExisting()
    return unmade.first.map { existing.appendingPathComponent($0) }
  }

  /// Each directory from `path` up to `top` that holds nothing; one holding
  /// anything stops the walk, `removeItem` taking a directory whole.
  private static func removeEmptyDirectories(from path: URL, through top: URL) {
    let manager = FileManager.default
    var directory = path.standardizedFileURL
    let last = top.standardizedFileURL.pathComponents.count
    while directory.pathComponents.count >= last {
      // `rmdir` refuses a directory with anything in it, a create beside this
      // one having perhaps made its checkout there since.
      if manager.fileExists(atPath: directory.path), rmdir(directory.path) != 0 { return }
      directory = directory.deletingLastPathComponent()
    }
  }
}
