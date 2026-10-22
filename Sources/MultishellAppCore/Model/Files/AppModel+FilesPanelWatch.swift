import Foundation
import MultishellCore
import MultishellGitKit

/// What a batch of file events re-reads of the Files panel's worktree, ahead
/// of the frontmost guard; see Docs/design/files.md.
extension AppModel {
  /// The panel's worktree is read on its own events, frontmost or not, and its
  /// tracked files when its project's git moved.
  func noteFilesPanelChanges(_ targets: FileChangeTargets) {
    guard showsFilesPanel, let worktree = filesPanelWorktree else { return }
    let expanded = expandedSubmodules(of: worktree.id).keys
    let gitMoved = targets.projectsWithGitChanges.contains(worktree.projectID)
    if gitMoved {
      scheduleTrackedFilesRead(of: worktree.id)
      // Its git directory sits under the parent's `.git/modules/`.
      for path in expanded { scheduleSubmoduleRead(path, in: worktree.id) }
    }
    // A checkout writes the index and the files in one batch; both are read.
    let changed = targets.fileChangesByWorktree[worktree.id] ?? []
    let changedEverything = changed.contains(FileChangeTargets.wholeWorktree)
    if !gitMoved {
      for path in expanded
      where changedEverything || changed.contains(where: { $0.hasPrefix(path + "/") || $0 == path })
      {
        scheduleSubmoduleRead(path, in: worktree.id)
      }
    }
    if !changed.isEmpty { scheduleIgnoredEntriesRead(of: worktree.id) }
    let readIgnoredFolders = (ignoredFolderEntries[worktree.id] ?? [:]).keys
    // A lock file or `.gitignore` is reported by its own path, not its folder's.
    let parents = changed.map { ($0 as NSString).deletingLastPathComponent }
    let changedFolders = Set(changed).union(parents)
    for path in readIgnoredFolders where changedEverything || changedFolders.contains(path) {
      scheduleIgnoredFolderRead(path, in: worktree.id)
    }
    guard !platform.isActive, platform.isWorkspaceWindowVisible,
      targets.mayHaveChangedStatus(of: worktree)
    else { return }
    scheduleStatusRefresh(of: worktree.id)
  }
}
