import Foundation
import MultishellCore

/// The captions under a project's worktree directory and branch prefix, from
/// the settings in force rather than what the form shows.
extension AppModel {
  public func worktreeContainerCaption(for project: Project, isOverridden: Bool) -> String {
    let container = effectiveWorktreeSettings(for: project).worktreeContainer(for: project).path
    return inherited(
      .worktreeDirectory, global: workspace.worktreeDefaults.worktreeDirectory, for: project
    )
    .containerCaption(container, isOverridden: isOverridden)
  }

  public func branchPrefixCaption(for project: Project, isOverridden: Bool) -> String {
    let effective = effectiveWorktreeSettings(for: project)
    let branch = effective.exampleBranch
    let path = effective.worktreePath(forBranch: branch, in: project).path
    return inherited(.branchPrefix, global: workspace.worktreeDefaults.branchPrefix, for: project)
      .prefixExampleCaption(branch: branch, path: path, isOverridden: isOverridden)
  }
}
