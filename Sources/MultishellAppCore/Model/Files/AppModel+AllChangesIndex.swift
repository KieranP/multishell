import MultishellCore

/// The Changes list as the All changes tab's index: a row's click shows the
/// tab at that file; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// A file row's click: on the Changes page the worktree's All changes tab at
  /// that file, opened if closed; on the Files page the file's own tab.
  public func activateFileRow(_ path: String, in id: Worktree.ID) async {
    guard shownFilesPanelMode == .changes else {
      await openFileAsTab(path, in: id)
      return
    }
    showFileInAllChangesTab(path, in: id)
  }

  /// The tab turned to, its view scrolling to `path`'s header once it can, and
  /// its row lit at once: a file near the end may not reach the top, the view
  /// then holding it lit until scrolled.
  public func showFileInAllChangesTab(_ path: String, in id: Worktree.ID) {
    guard let tab = openAllChangesTab(in: id) else { return }
    allChangesFileReveals[tab.id] = path
    noteAllChangesTopFile(AllChangesTopFile(path: path, isHeaderScrolledPast: false), in: tab.id)
  }

  /// The view's, as it updates. Read first, as a removal of nothing still
  /// redraws every All changes tab.
  public func takeAllChangesFileReveal(_ id: AllChangesTab.ID) -> String? {
    guard allChangesFileReveals[id] != nil else { return nil }
    return allChangesFileReveals.removeValue(forKey: id)
  }
}
