import Foundation
import MultishellCore
import MultishellGitKit

/// A file tab opened from the Files panel or the quick switcher, by the
/// clicked-link rule; see Docs/design/files/file-tabs.md.
extension AppModel {
  /// A click on a file's row: its tab, else a beep.
  public func openFileAsTab(_ clicked: String, in id: Worktree.ID) async {
    _ = await openFileAsTab(clicked, in: id, as: .click)
  }

  /// The tab where the file opens as text or an image (files/image-tabs.md), else `nil`; a
  /// gone file is judged on git's copy. The caller drops the listing it built.
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
    // The image rule first, as it reads only the name where the text rule reads the start.
    var opens = await runOnDispatch { platform.opensAsImage(url) || platform.opensAsText(url) }
    if !opens, await !runOnDispatch({ FileManager.default.fileExists(atPath: url.path) }),
      let git = coordinator?.git
    {
      opens = await opensGoneFile(path, in: worktree.path, git: git)
    }
    guard opens, workspace.worktree(id) != nil else {
      if asker == .click { platform.beep() }
      return nil
    }
    let tab = store.openFileTab(path: path, in: id)
    reconcileSessions(takingFocus: asker == .click || worktreeIDInView == id)
    return tab
  }

  /// By git's copy, a submodule's own for a file inside one: an image's name needs
  /// only that there is a copy, text its start.
  private func opensGoneFile(_ path: String, in worktree: URL, git: WorktreeGit) async -> Bool {
    let name = (path as NSString).lastPathComponent
    let platform = self.platform
    let (repository, isImage) = await runOnDispatch {
      (
        RepositoryLocation.innermost(holding: path, in: worktree),
        platform.opensAsImage(named: name),
      )
    }
    if isImage { return await git.hasStoredCopy(of: repository.path, in: repository.directory) }
    guard
      let start = await git.storedCopyStart(
        of: repository.path,
        in: repository.directory,
        byteCount: TextFileStart.byteCount,
        sizeLimit: FileTabReader.sizeLimit,
      )
    else { return false }
    return platform.opensAsText(named: name, startingWith: start)
  }
}
