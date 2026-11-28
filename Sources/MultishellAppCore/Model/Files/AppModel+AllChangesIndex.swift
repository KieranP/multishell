import Foundation
import MultishellCore
import MultishellGitKit

/// The Changes list as the All changes tab's index: a row's click shows the
/// tab at that file; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// A file row's click: the All changes tab at that file on the Changes page; the
  /// file's own tab on the Files page or for a file the tab does not list.
  public func activateFileRow(_ path: String, in id: Worktree.ID) async {
    guard shownFilesPanelMode == .changes, await allChangesTabMayList(path, in: id) else {
      await openFileAsTab(path, in: id)
      return
    }
    showFileInAllChangesTab(path, in: id)
  }

  /// Listed by git, or its list still to land, and deleted or not a folder: a
  /// submodule's change, which the tab's read leaves out. Off the main actor, as a dead mount holds an lstat.
  private func allChangesTabMayList(_ path: String, in id: Worktree.ID) async -> Bool {
    guard let changes = allChangesListedChanges(of: id) else { return true }
    guard let change = changes.first(where: { $0.path == path }),
      let worktree = workspace.worktree(id)
    else { return false }
    if change.kind == .deleted { return true }
    let url = worktree.path.appending(path: path)
    return await runOnDispatch { FileSignature.of(url)?.isFolder != true }
  }

  /// The tab turned to, `path` expanded, scrolled to and lit at once: a file near
  /// the end may never reach the top, so the view holds it lit until scrolled.
  func showFileInAllChangesTab(_ path: String, in id: Worktree.ID) {
    guard let tab = openAllChangesTab(in: id) else { return }
    expandAllChangesFile(path, in: tab.id)
    allChangesFileReveals[tab.id] = path
    noteAllChangesTopFile(AllChangesTopFile(path: path, isHeaderScrolledPast: false), in: tab.id)
  }

  /// A file picked from elsewhere shows its rows, not a collapsed header.
  func expandAllChangesFile(_ path: String, in id: AllChangesTab.ID) {
    guard allChangesCollapsedFiles[id]?.contains(path) == true else { return }
    relayingOutAllChanges(id) { _ = allChangesCollapsedFiles[id]?.remove(path) }
  }

  /// The view's, as it updates. Read first, as a removal of nothing still
  /// redraws every All changes tab.
  public func takeAllChangesFileReveal(_ id: AllChangesTab.ID) -> String? {
    guard allChangesFileReveals[id] != nil else { return nil }
    return allChangesFileReveals.removeValue(forKey: id)
  }
}
