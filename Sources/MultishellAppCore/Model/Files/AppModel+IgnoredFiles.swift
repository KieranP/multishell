import MultishellCore

/// Show Hidden Files: whether the Files panel and the quick switcher list what
/// git ignores; see Docs/design/files/panel.md.
extension AppModel {
  var showsIgnoredFiles: Bool { workspace.showsIgnoredFiles }

  /// Hidden, what git ignores is neither read nor listed, a read under way
  /// stopped; shown again, it is read for the panel and the quick switcher.
  public func setShowsIgnoredFiles(_ shows: Bool) {
    guard showsIgnoredFiles != shows else { return }
    store.setShowsIgnoredFiles(shows)
    guard shows else {
      ignoredEntriesReads.cancel { _ in true }
      panelFolderReads.cancel { $0.kind == .ignoredFolder }
      return
    }
    if isFileListOnScreen, let worktree = filesPanelWorktree {
      scheduleIgnoredReads(of: worktree.id)
    }
    if quickSwitcher?.listsFiles == true, let id = workspace.selectedWorktreeID {
      scheduleIgnoredEntriesRead(of: id)
    }
  }
}
