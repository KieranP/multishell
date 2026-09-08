import Foundation
import MultishellCore

// MARK: - What order a project's worktree rows come in

extension AppModel {
  /// Orders a project's rows as its settings ask.
  ///
  /// Takes the worktrees rather than reading them, so the filtered list the
  /// sidebar draws is ordered the same way a whole one is.
  public func ordered(_ worktrees: [Worktree], in project: Project) -> [Worktree] {
    worktreeOrder(for: project).sort(
      worktrees,
      displayName: { self.workspace.displayName(of: $0) },
      isActive: { self.isActive($0.id) },
      lastCommit: { self.lastCommits[$0.id] })
  }

  /// The rule in force for a project: its own choices where it made them,
  /// the global otherwise, measured against the trunk the merge badges use.
  ///
  /// The record is looked up again rather than read off the value handed in:
  /// the settings window is its own scene, so the order can change while a
  /// caller still holds the project as it was when it drew.
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
