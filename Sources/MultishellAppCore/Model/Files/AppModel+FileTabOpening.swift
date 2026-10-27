import Foundation
import MultishellCore
import MultishellGitKit

/// A file tab opened from the Files panel or the quick switcher, by the
/// clicked-link rule; see Docs/design/files.md.
extension AppModel {
  /// A tab where a clicked link would open the file as text, `true`, else a
  /// beep; a file gone from disk is judged on git's copy.
  @discardableResult
  public func openFileAsTab(_ clicked: String, in id: Worktree.ID) async -> Bool {
    guard let worktree = workspace.worktree(id), FileTab.isContained(clicked) else { return false }
    guard fileTree(of: id).isOpenable(clicked),
      let path = await runOnDispatch({ WorktreeLinkTarget.path(of: clicked, in: worktree.path) })
    else {
      platform.beep()
      return false
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
      return false
    }
    store.openFileTab(path: path, in: id)
    reconcileSessions(takingFocus: true)
    return true
  }
}
