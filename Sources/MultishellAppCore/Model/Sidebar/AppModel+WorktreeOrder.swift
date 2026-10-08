import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Orders a project's rows as its settings ask. Takes the worktrees rather
  /// than reading them, so a filtered list orders like a whole one.
  public func orderedWorktrees(
    _ worktrees: [Worktree], in project: Project, sessions: SessionIDsByWorktree
  ) -> [Worktree] {
    let rule = worktreeSortRule(for: project)
    let keys = rule.keys(
      worktrees,
      displayName: { self.workspace.displayName(of: $0) },
      isActive: { self.isActiveWorktree($0.id, sessions: sessions) },
      lastCommit: { self.lastCommitDates[$0.id] })
    return worktreeSortCache.rows(of: project.id, keys: keys, rule: rule)
  }

  /// The rule in force for a project, measured against the merge badges'
  /// trunk. Looked up again, the settings window being its own scene.
  private func worktreeSortRule(for project: Project) -> WorktreeSortRule {
    let effective = effectiveProject(currentCopy(of: project))
    return WorktreeSortRule(
      sortOrder: workspace.effectiveWorktreeSortOrder(for: effective),
      showsActiveFirst: workspace.showsActiveWorktreesFirst(for: effective),
      trunkBranch: defaultBranch(of: project)?.nameWithoutRemote)
  }

  /// Whether anything is going on in a worktree: a terminal open in it, or
  /// a state something reported for it.
  func isActiveWorktree(_ id: Worktree.ID, sessions: SessionIDsByWorktree) -> Bool {
    !sessions[id].isEmpty || state(ofWorktree: id, sessions: sessions) != nil
  }

  public func setWorktreeSortOrder(_ order: WorktreeSortOrder) {
    store.setWorktreeSortOrder(order)
  }

  public func setShowsActiveWorktreesFirst(_ enabled: Bool) {
    store.setShowsActiveWorktreesFirst(enabled)
  }
}
