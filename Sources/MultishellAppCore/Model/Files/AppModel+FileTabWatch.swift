import Foundation
import MultishellCore

/// Which file tabs a watcher batch moved, heard ahead of the frontmost and
/// ignored-folder guards; see Docs/design/files.md.
extension AppModel {
  /// A change in a tab's folder re-reads it where its `lstat` moved, and one in
  /// its project's git always, the diff's other side having moved.
  func noteFileTabChanges(_ targets: FileChangeTargets) {
    for tab in workspace.fileTabs {
      guard let worktree = workspace.worktree(tab.worktreeID) else { continue }
      if targets.projectsWithGitChanges.contains(worktree.projectID) {
        noteFileTabChanged(tab.id)
        continue
      }
      let folder = tab.path.split(separator: "/").dropLast().joined(separator: "/")
      let isTouched = (targets.fileChangesByWorktree[worktree.id] ?? []).contains { path in
        path == FileChangeTargets.wholeWorktree || path == folder || path == tab.path
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
