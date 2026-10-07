import Foundation
import MultishellCore

extension WorktreeGit {
  /// A lock older than this is an add that died mid-checkout, git's own
  /// cleanup running only on a signal it can catch; see worktrees.md.
  private static let abandonedAddAge: TimeInterval = 10 * 60

  /// git's `initializing` is in the user's language, so a lock from before
  /// `gitdir` over files with no index yet counts too; see worktrees.md.
  static func judgedInitializing(_ worktree: Worktree) -> Worktree {
    guard worktree.isLocked else { return worktree }
    let record = Self.recordDirectoryFromGitFile(in: worktree.path)
    let lockedAt =
      record.flatMap { $0.appendingPathComponent("locked").modificationDate } ?? worktree.createdAt
    if !worktree.isInitializing {
      guard let record,
        !FileManager.default.fileExists(atPath: record.appendingPathComponent("index").path),
        let lockedAt, let linkedAt = record.appendingPathComponent("gitdir").modificationDate,
        lockedAt <= linkedAt, hasCheckedOutFiles(worktree.path)
      else { return worktree }
    }
    var marked = worktree
    marked.isInitializing = lockedAt.map { -$0.timeIntervalSinceNow < abandonedAddAge } ?? false
    return marked
  }

  /// `add --no-checkout` writes nothing beside `.git`, and one made with
  /// `--lock` looks otherwise like an add still checking out.
  private static func hasCheckedOutFiles(_ checkout: URL) -> Bool {
    let entries = (try? FileManager.default.contentsOfDirectory(atPath: checkout.path)) ?? []
    return entries.contains { $0 != ".git" }
  }
}
