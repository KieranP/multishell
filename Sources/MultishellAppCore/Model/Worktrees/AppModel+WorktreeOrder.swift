import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Orders a project's rows as its settings ask. Takes the worktrees rather
  /// than reading them, so a filtered list orders like a whole one.
  public func orderedWorktrees(
    _ worktrees: [Worktree], in project: Project, sessions: WorktreeSessions? = nil
  ) -> [Worktree] {
    let sessions = sessions ?? worktreeSessions
    let order = worktreeOrder(for: project)
    let keys = order.keys(
      worktrees,
      displayName: { self.workspace.displayName(of: $0) },
      isActive: { self.hasActivity($0.id, sessions: sessions) },
      lastCommit: { self.lastCommits[$0.id] })
    return worktreeOrderMemo.rows(of: project.id, keys: keys, order: order)
  }

  /// The rule in force for a project, measured against the merge badges'
  /// trunk. Looked up again, the settings window being its own scene.
  private func worktreeOrder(for project: Project) -> WorktreeOrder {
    let resolved = withEffectiveSettings(workspace.project(project.id) ?? project)
    return WorktreeOrder(
      sortOrder: workspace.worktreeSortOrder(for: resolved),
      activeFirst: workspace.showsActiveWorktreesFirst(for: resolved),
      trunkBranch: defaultBranch(of: project)?.branchName)
  }

  /// Whether anything is going on in a worktree: a terminal open in it, or
  /// a state something reported for it.
  func hasActivity(_ id: Worktree.ID, sessions: WorktreeSessions? = nil) -> Bool {
    let sessions = sessions ?? worktreeSessions
    return !sessions[id].isEmpty || state(ofWorktree: id, sessions: sessions) != nil
  }

  public func setWorktreeSortOrder(_ order: WorktreeSortOrder) {
    store.setWorktreeSortOrder(order)
  }

  public func setShowsActiveWorktreesFirst(_ enabled: Bool) {
    store.setShowsActiveWorktreesFirst(enabled)
  }
}
