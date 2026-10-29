import Foundation
import MultishellCore
import MultishellGitKit

/// A file tab opened from the Files panel or the quick switcher, by the
/// clicked-link rule; see Docs/design/files.md.
extension AppModel {
  /// A click on a file's row: its tab, else a beep.
  public func openFileAsTab(_ clicked: String, in id: Worktree.ID) async {
    _ = await openFileAsTab(clicked, in: id, as: .click)
  }

  /// The tab where a clicked link would open the file as text, else `nil`; a file
  /// gone from disk is judged on git's copy. The caller drops the listing it built.
  func openFileAsTab(
    _ clicked: String,
    in id: Worktree.ID,
    as asker: Asker,
  ) async -> FileTab? {
    guard let worktree = workspace.worktree(id), FileTab.isContained(clicked) else { return nil }
    guard fileTree(of: id).isOpenable(clicked),
      let path = await runOnDispatch({ WorktreeLinkTarget.path(of: clicked, in: worktree.path) })
    else {
      if asker == .click { platform.beep() }
      return nil
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
      if asker == .click { platform.beep() }
      return nil
    }
    let tab = store.openFileTab(path: path, in: id)
    reconcileSessions(takingFocus: asker == .click || worktreeIDInView == id)
    return tab
  }
}
