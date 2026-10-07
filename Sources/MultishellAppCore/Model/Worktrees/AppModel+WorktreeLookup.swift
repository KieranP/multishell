import Foundation
import MultishellCore

/// Which worktree a path is in, for a report that names only a directory.
extension AppModel {
  /// The deepest worktree holding the directory. A hook's `workingDirectory` may be the
  /// resolved path of one added through a symlink, so both spellings are tried.
  func worktree(atPath path: String) -> Worktree? {
    recheckResolutionsMadeWhileMissing()
    let url = URL(fileURLWithPath: path, isDirectory: true)
    let spellings = [url.standardizedFileURL, url.resolvingSymlinksInPath()].map(\.pathComponents)
    // Depth is the matching root's, not the written path's: a symlink chain
    // can spell a shallow worktree long.
    let matches = workspace.worktrees.compactMap { worktree -> (Worktree, Int)? in
      let depth = [worktree.path.pathComponents, resolvedComponents(of: worktree)]
        .filter { root in spellings.contains { $0.starts(with: root) } }
        .map(\.count).max()
      return depth.map { (worktree, $0) }
    }
    return matches.max { $0.1 < $1.1 }?.0
  }

  /// Kept per worktree: each report naming only a directory walked every
  /// worktree's symlinks, on the main actor, a network mount's among them.
  private func resolvedComponents(of worktree: Worktree) -> [String] {
    if let known = resolvedWorktreeComponents[worktree.id] { return known }
    let resolved = worktree.path.resolvingSymlinksInPath().pathComponents
    resolvedWorktreeComponents[worktree.id] = resolved
    resolveAgainOffMain(worktree, replacing: resolved)
    return resolved
  }

  /// Foundation hands back a missing path unresolved. Checked off the main
  /// actor, which the kept resolution is there to spare.
  private func resolveAgainOffMain(_ worktree: Worktree, replacing resolved: [String]) {
    let path = worktree.path
    Task {
      let (again, exists) = await runOnDispatch {
        let again = path.resolvingSymlinksInPath()
        return (again.pathComponents, FileManager.default.fileExists(atPath: again.path))
      }
      // Forgotten or made again meanwhile, so not this resolution's to judge.
      guard resolvedWorktreeComponents[worktree.id] == resolved else { return }
      resolvedWorktreeComponents[worktree.id] = again
      if !exists { worktreesResolvedWhileMissing.insert(worktree.id) }
    }
  }

  /// A report may name the real path of a worktree nobody polls, so each one
  /// looks again, off the main actor, for the directories that were away.
  private func recheckResolutionsMadeWhileMissing() {
    let due = worktreesResolvedWhileMissing.subtracting(resolutionsBeingRechecked)
    guard !due.isEmpty else { return }
    for worktree in workspace.worktrees where due.contains(worktree.id) {
      resolutionsBeingRechecked.insert(worktree.id)
      let path = worktree.path
      Task {
        let isPresent = await runOnDispatch { FileManager.default.fileExists(atPath: path.path) }
        resolutionsBeingRechecked.remove(worktree.id)
        if isPresent { noteDirectoryPresent(of: worktree.id) }
      }
    }
  }

  /// Something off the main actor found the directory, so a resolution made
  /// while it was away is made again at the next report.
  func noteDirectoryPresent(of id: Worktree.ID) {
    guard worktreesResolvedWhileMissing.remove(id) != nil else { return }
    resolvedWorktreeComponents[id] = nil
  }
}
