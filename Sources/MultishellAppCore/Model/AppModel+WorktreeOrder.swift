import Foundation
import MultishellCore

// MARK: - What order a project's worktree rows come in

extension AppModel {
  /// Orders a project's rows as its settings ask. Takes the worktrees rather
  /// than reading them, so a filtered list orders like a whole one.
  public func ordered(_ worktrees: [Worktree], in project: Project) -> [Worktree] {
    worktreeOrder(for: project).sort(
      worktrees,
      displayName: { self.workspace.displayName(of: $0) },
      isActive: { self.isActive($0.id) },
      lastCommit: { self.lastCommits[$0.id] })
  }

  /// The rule in force for a project, measured against the merge badges'
  /// trunk. Looked up again, the settings window being its own scene.
  public func worktreeOrder(for project: Project) -> WorktreeOrder {
    let resolved = resolved(workspace.project(project.id) ?? project)
    return WorktreeOrder(
      order: workspace.worktreeSortOrder(for: resolved),
      activeFirst: workspace.showsActiveWorktreesFirst(for: resolved),
      trunkBranch: mergeBase(of: project)?.branch)
  }

  /// Whether anything is going on in a worktree: a terminal open in it, or
  /// a state something reported for it.
  public func isActive(_ id: Worktree.ID) -> Bool {
    !workspace.sessions(in: id).isEmpty || state(ofWorktree: id) != nil
  }

  public func setWorktreeSortOrder(_ order: WorktreeSortOrder) {
    store.setWorktreeSortOrder(order)
  }

  public func setShowsActiveWorktreesFirst(_ enabled: Bool) {
    store.setShowsActiveWorktreesFirst(enabled)
  }
}
