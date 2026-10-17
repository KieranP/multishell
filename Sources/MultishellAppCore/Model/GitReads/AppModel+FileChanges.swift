import Foundation
import MultishellCore
import MultishellGitKit

extension AppModel {
  /// How long a burst of changes is given to settle before git reads it: one
  /// checkout or save writes several files.
  static var changeSettleDelay: Duration { .milliseconds(250) }

  /// A watcher tick. git's records are compared frontmost or not, as a new
  /// worktree is a row; badges are read frontmost only, as the poll's are.
  func noteFileChanges(_ changed: [URL]) async {
    let (projects, worktrees, gitDirectories) =
      (workspace.projects, workspace.worktrees, commonGitDirectories)
    var targets = fileChangeTargets(changed)
    if targets.hasThemeChanges { await reloadThemes() }
    noteFileTabChanges(targets)
    noteFilesPanelChanges(targets)
    await refreshProjectsIfChanged(withGitDirectoryChanges: targets.projectsWithGitDirectoryChanges)
    guard platform.isActive else { return }
    // Again only where the awaits changed what a change is matched against;
    // see worktrees.md for its cost.
    if workspace.projects != projects || workspace.worktrees != worktrees
      || commonGitDirectories != gitDirectories
    {
      targets = fileChangeTargets(changed)
    }
    forgetIgnoreVerdicts(changedBy: targets)
    let onSidebar = sidebarRowIDs()
    for worktree in workspace.worktrees
    where targets.mayHaveChangedStatus(of: worktree)
      && isStatusWanted(worktree, onSidebar: onSidebar)
    {
      if !targets.projectsWithGitChanges.contains(worktree.projectID) {
        let changes = targets.fileChangesByWorktree[worktree.id] ?? []
        guard await hasChangesGitDoesNotIgnore(changes, in: worktree) else { continue }
      }
      scheduleStatusRefresh(of: worktree.id)
    }
    for id in targets.projectsWithGitChanges { scheduleBranchScan(of: id) }
    for project in workspace.projects
    where targets.projectsWithSharedSettingsChanges.contains(project.id) {
      await refreshSharedSettingsIfChanged(project)
    }
  }

  func fileChangeTargets(_ changed: [URL]) -> FileChangeTargets {
    FileChangeTargets(
      changed: changed,
      projects: workspace.projects,
      gitDirectories: commonGitDirectories,
      worktrees: workspace.worktrees,
      themesDirectory: themesDirectory,
    )
  }

  /// Whether any change lies outside what git ignores, so `npm install` filling
  /// `node_modules` reads no status. git is asked once per directory.
  private func hasChangesGitDoesNotIgnore(_ paths: [String], in worktree: Worktree) async -> Bool {
    guard let coordinator else { return true }
    guard !paths.contains(FileChangeTargets.wholeWorktree) else { return true }
    var verdicts = ignoreVerdicts[worktree.id] ?? IgnoreVerdicts()
    while true {
      let notIgnored = paths.filter { verdicts.isIgnored($0) == false }
      if !notIgnored.isEmpty {
        // A directory swapped in arrives as its parent alone, with no word of
        // the `.gitignore` it brought, so what lies under it is asked afresh.
        ignoreVerdicts[worktree.id]?.forget(below: Set(notIgnored))
        return true
      }
      let unasked = verdicts.unasked(on: paths)
      guard !unasked.isEmpty else { return false }
      guard let ignored = await coordinator.git.ignoredPaths(unasked, in: worktree.path) else {
        return true
      }
      guard workspace.worktree(worktree.id) != nil else { return false }
      verdicts.record(asked: unasked, ignored: ignored)
      // A directory-only pattern matches nothing while the directory is gone,
      // either way: `node_modules/` reads not ignored, `!/gen/` ignored.
      let worktreePath = worktree.path
      let present = await runOnDispatch {
        unasked.filter { path in
          FileManager.default.fileExists(atPath: worktreePath.appending(path: path).path)
        }
      }
      ignoreVerdicts[worktree.id, default: IgnoreVerdicts()].record(
        asked: present,
        ignored: ignored,
      )
    }
  }

  /// A `.gitignore` changed, or the project's git state did: `info/exclude`,
  /// or the index taking a file forced in under an ignored directory.
  private func forgetIgnoreVerdicts(changedBy targets: FileChangeTargets) {
    for worktree in workspace.worktrees
    where targets.worktreesWithIgnoreRuleChanges.contains(worktree.id)
      || targets.projectsWithGitChanges.contains(worktree.projectID)
    {
      ignoreVerdicts[worktree.id] = nil
    }
  }
}
