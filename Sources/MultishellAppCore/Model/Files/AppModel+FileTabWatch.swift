import Foundation
import MultishellCore

/// Which file tabs a watcher batch moved, heard ahead of the frontmost and
/// ignored-folder guards; see Docs/design/files/file-tabs.md.
extension AppModel {
  /// A change in a tab's folder re-reads it where its `lstat` moved, and one in
  /// the git it diffs against always, the diff's other side having moved.
  func noteFileTabChanges(_ targets: FileChangeTargets) {
    for tab in workspace.fileTabs {
      guard let worktree = workspace.worktree(tab.worktreeID) else { continue }
      let embedded = targets.embeddedRepositoriesWithGitChanges[worktree.id] ?? []
      if targets.projectsWithGitChanges.contains(worktree.projectID)
        || embedded.contains(where: tab.path.isPath(under:))
      {
        noteFileTabChanged(tab.id)
        continue
      }
      // A folder moved or trashed above the tab is heard only at its own parent.
      let isTouched = (targets.fileChangesByWorktree[worktree.id] ?? []).contains { path in
        path == FileChangeTargets.wholeWorktree || path == tab.path || tab.path.isPath(under: path)
      }
      if isTouched { checkFileTabSignature(tab, in: worktree) }
    }
  }

  /// Off the main actor, a dead mount being able to hold an `lstat`.
  private func checkFileTabSignature(_ tab: FileTab, in worktree: Worktree) {
    let url = worktree.path.appending(path: tab.path)
    Task { @MainActor [weak self] in
      let signature = await runOnDispatch { FileSignature.of(url) }
      guard let self, workspace.fileTab(tab.id) != nil,
        fileTabReadLog.signature(of: tab.id) != signature
      else { return }
      fileTabReadLog.note(signature, of: tab.id)
      noteFileTabChanged(tab.id)
    }
  }
}
