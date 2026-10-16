import Foundation
import MultishellCore
import MultishellGitKit

/// A file tab opened from the Files panel, by the clicked-link rule; see
/// Docs/design/files.md.
extension AppModel {
  /// A click on a file row: a tab where a clicked link would open it as text,
  /// else a beep. A file gone from disk is judged on git's copy.
  public func openFileFromPanel(_ clicked: String, in id: Worktree.ID) async {
    guard let worktree = workspace.worktree(id), FileTab.isContained(clicked) else { return }
    guard fileTree(of: id).isOpenable(clicked),
      let path = await runOnDispatch({ WorktreeLinkTarget.path(of: clicked, in: worktree.path) })
    else {
      platform.beep()
      return
    }
    let url = worktree.path.appending(path: path)
    let platform = self.platform
    var opens = await runOnDispatch { platform.opensAsText(url) }
    if !opens, await !runOnDispatch({ FileManager.default.fileExists(atPath: url.path) }),
      let start = await coordinator?.git.storedCopyStart(
        of: path,
        in: worktree.path,
        byteCount: TextFileStart.byteCount,
        sizeLimit: FileTabReader.sizeLimit,
      )
    {
      opens = platform.opensAsText(named: url.lastPathComponent, startingWith: start)
    }
    guard opens, workspace.worktree(id) != nil else {
      platform.beep()
      return
    }
    store.openFileTab(path: path, in: id)
    reconcileSessions(takingFocus: true)
  }
}
