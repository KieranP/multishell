import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// Orders a project's rows as its settings ask. Takes the worktrees rather
  /// than reading them, so a filtered list orders like a whole one.
  func orderedWorktrees(
    _ worktrees: [Worktree],
    in project: Project,
    sessions: SessionIDsByWorktree,
  ) -> [Worktree] {
    let rule = worktreeSortRule(for: project)
    // Read once, not per row: a generic model's observed read builds its key
    // path each time, about 30 times a plain class's (quick-switcher.md).
    let workspace = workspace
    let states = sessionStates
    let commitDates = lastCommitDates
    let keys = rule.keys(
      worktrees,
      displayName: { workspace.displayName(of: $0) },
      isActive: { states.isActive(worktree: $0.id, sessions: sessions[$0.id]) },
      lastCommit: { commitDates[$0.id] },
    )
    return worktreeSortCache.rows(of: project.id, keys: keys, rule: rule)
  }

  /// An entry's worktrees and its hidden ones, ordered as one list and then
  /// split, so the sort cache holds one entry per project.
  public func orderedWorktrees(
    of entry: SidebarListing.Entry,
    sessions: SessionIDsByWorktree,
  ) -> (worktrees: [Worktree], hiddenWorktrees: [Worktree]) {
    let ordered = orderedWorktrees(
      entry.worktrees + entry.hiddenWorktrees,
      in: entry.project,
      sessions: sessions,
    )
    let hiddenIDs = Set(entry.hiddenWorktrees.map(\.id))
    return (
      ordered.filter { !hiddenIDs.contains($0.id) },
      ordered.filter { hiddenIDs.contains($0.id) },
    )
  }

  /// The rule in force for a project, measured against the merge badges'
  /// trunk. Looked up again, the settings window being its own scene.
  private func worktreeSortRule(for project: Project) -> WorktreeSortRule {
    let effective = effectiveProject(currentCopy(of: project))
    return WorktreeSortRule(
      sortOrder: workspace.effectiveWorktreeSortOrder(for: effective),
      showsActiveFirst: workspace.showsActiveWorktreesFirst(for: effective),
      trunkBranch: defaultBranch(of: project)?.nameWithoutRemote,
    )
  }

  func isActiveWorktree(_ id: Worktree.ID, sessions: SessionIDsByWorktree) -> Bool {
    sessionStates.isActive(worktree: id, sessions: sessions[id])
  }

  public func setWorktreeSortOrder(_ order: WorktreeSortOrder) {
    store.setWorktreeSortOrder(order)
  }

  public func setShowsActiveWorktreesFirst(_ enabled: Bool) {
    store.setShowsActiveWorktreesFirst(enabled)
  }
}
