import MultishellCore

/// The tabs review cards are written in: a file tab, on its one file, or the
/// All changes tab, on any of its files.
extension AppModel {
  func reviewWorktree(of tabID: ReviewTabID) -> Worktree.ID? {
    switch workspace.workspaceTab(tabID) {
    case .allChanges(let tab): tab.worktreeID
    case .file(let tab): tab.worktreeID
    case .terminal, nil: nil
    }
  }

  /// `path`'s rows as the tab last read them, every line of the file folded
  /// or not; `nil` where it holds none of that file.
  func reviewRows(ofFile path: String, in tabID: ReviewTabID) -> [DiffLine]? {
    switch workspace.workspaceTab(tabID) {
    case .allChanges:
      return allChangesReadings[tabID]?.files.first { $0.path == path }?.rows?.lines

    case .file(let tab):
      guard tab.path == path, case .text(let rows) = fileTabReadings[tabID]?.content else {
        return nil
      }
      return rows.lines

    case .terminal, nil:
      return nil
    }
  }
}
