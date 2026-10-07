import Foundation
import MultishellCore

extension AppModel {
  /// As the sidebar names the worktree: its project and its display name.
  func debugLocation(of worktree: Worktree) -> DebugLocation {
    DebugLocation(
      projectName: workspace.project(worktree.projectID)?.name,
      worktreeName: displayName(of: worktree))
  }

  /// Each worktree by its root's standardized path, built once for a table
  /// rather than searched for every row.
  func worktreesByStandardizedPath() -> [String: Worktree] {
    Dictionary(
      keepingFirst:
        workspace.worktrees.map { ($0.path.standardizedFileURL.path, $0) })
  }

  /// Matched exactly, git running at a worktree's root: the lookup a report
  /// uses resolves symlinks and spawns a check, too much for a render.
  func debugLocation(
    ofDirectory directory: URL, in worktreesByPath: [String: Worktree]
  ) -> DebugLocation {
    guard let worktree = worktreesByPath[directory.standardizedFileURL.path] else {
      return DebugLocation(projectName: nil, worktreeName: directory.lastPathComponent)
    }
    return debugLocation(of: worktree)
  }
}
