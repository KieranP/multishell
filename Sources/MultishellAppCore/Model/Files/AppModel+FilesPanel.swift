import Foundation
import MultishellCore
import MultishellGitKit

/// The Files panel: what it lists, the switch, the filter and its folders;
/// see Docs/design/files/panel.md.
extension AppModel {
  /// The worktree the panel lists, where the panel can be: a worktree with
  /// tabs or with none, not an operation or a cover.
  var filesPanelWorktree: Worktree? {
    switch detailContent {
    case .noTabs(let worktree), .tabGroups(let worktree): worktree
    case .cover, .noSelection, .operation: nil
    }
  }

  public var showsFilesPanel: Bool { workspace.showsFilesPanel }

  /// Open, and with a worktree to list: what both edges' widths allow for.
  public var isFilesPanelOnScreen: Bool { showsFilesPanel && filesPanelWorktree != nil }

  /// Files or Changes shows: a services' page lists no files, so reads none.
  var isFileListOnScreen: Bool { isFilesPanelOnScreen && shownFilesPanelMode.listsFiles }

  /// Modified or Branch, drawn over the Changes list alone, Files counting from `HEAD`.
  public var filesPanelShowsChangeScopeSwitch: Bool { shownFilesPanelMode == .changes }

  /// Where the panel can be but is shut: open, its own header carries the toggle.
  public var worktreeHeaderShowsFilesPanelToggle: Bool {
    !showsFilesPanel && filesPanelWorktree != nil
  }

  /// The header glyph's and the View menu's, kept for the next launch.
  public func setShowsFilesPanel(_ shows: Bool) {
    guard showsFilesPanel != shows else { return }
    store.setShowsFilesPanel(shows)
    if shows, let worktree = filesPanelWorktree {
      readFilesPanel(of: worktree.id)
    } else if !shows {
      forgetUnreadFileListings()
    }
  }

  public func toggleFilesPanel() {
    setShowsFilesPanel(!showsFilesPanel)
  }

  /// The rows' fit, measured only where asked: a services' page wraps its text
  /// rather than cut it, so a double-click on the edge puts it back to its first width.
  public func filesPanelWidthOnDoubleClick(fittingRows rowsWidth: () -> Double) -> Double {
    shownFilesPanelMode.listsFiles ? rowsWidth() : FilesPanelWidth.initial
  }

  /// A click on a worktree row's git badge: that worktree, the panel open on
  /// what the badge counts, its Changes list under Modified.
  public func showModifiedFiles(of worktree: Worktree) {
    guard selectForPanel(worktree) else { return }
    setChangeScope(.modified)
    setFilesPanelMode(.changes)
    filesPanelStates[worktree.id]?.filterText = ""
    setShowsFilesPanel(true)
  }

  /// A click on a worktree row's pull request or CI glyph: that worktree,
  /// the panel open on the glyph's page.
  public func showFilesPanel(_ mode: FilesPanelMode, of worktree: Worktree) {
    guard selectForPanel(worktree) else { return }
    setFilesPanelMode(mode)
    setShowsFilesPanel(true)
  }

  private func selectForPanel(_ worktree: Worktree) -> Bool {
    if workspace.selectedWorktreeID != worktree.id || detailCover != nil {
      return select(worktree)
    }
    return true
  }

  public func filesPanelState(of id: Worktree.ID) -> FilesPanelState {
    var state = filesPanelStates[id] ?? FilesPanelState()
    state.mode = shownFilesPanelMode
    return state
  }

  /// The panel's page, kept for every worktree's panel and the next launch.
  /// Leaving or reaching a services' page reads what the new one shows.
  public func setFilesPanelMode(_ mode: FilesPanelMode) {
    guard workspace.filesPanelMode != mode else { return }
    store.setFilesPanelMode(mode)
    forgetBranchChangesUnlessListed()
    schedulePanelBranchChangesRead()
    readFilesPanelIfItsKindChanged()
  }

  /// Only a move between two pages that list files keeps the listing as read;
  /// a tool coming or going changes the page too.
  func readFilesPanelIfItsKindChanged() {
    let shown = shownFilesPanelMode
    let previous = remoteState.lastReadFilesPanelMode ?? shown
    if shown != previous, !(shown.listsFiles && previous.listsFiles), isFilesPanelOnScreen,
      let worktree = filesPanelWorktree
    {
      readFilesPanel(of: worktree.id)
    }
  }

  public func setFilesPanelFilterText(_ text: String, in id: Worktree.ID) {
    guard filesPanelState(of: id).filterText != text else { return }
    filesPanelStates[id, default: FilesPanelState()].filterText = text
  }

  /// Opens or shuts a folder in whichever list the panel shows. A submodule
  /// opening is read as a repository of its own.
  public func toggleFolder(_ row: FileTreeRow, in id: Worktree.ID) {
    let path = row.path
    var state = filesPanelState(of: id)
    switch state.mode {
    case .files:
      if state.expandedFolders.remove(path) == nil {
        state.expandedFolders.insert(path)
        if row.isRepository { scheduleSubmoduleRead(path, in: id) }
        if row.isIgnored { scheduleIgnoredFolderRead(path, in: id) }
      }

    case .changes:
      if state.collapsedChangesFolders.remove(path) == nil {
        state.collapsedChangesFolders.insert(path)
      }

    case .ciRuns, .pullRequest, .review:
      return
    }
    filesPanelStates[id] = state
  }

  /// Kept between renders: a filter over 200,000 paths cost most of a second.
  public func fileTreeRows(of id: Worktree.ID) -> [FileTreeRow] {
    let tree = fileTree(of: id)
    let state = filesPanelState(of: id)
    if let kept = fileTreeCache[id]?.rows, kept.state == state { return kept.rows }
    let rows = tree.rows(state: state)
    fileTreeCache[id]?.rows = (state, rows)
    return rows
  }

  public func filesPanelSummary(of id: Worktree.ID) -> FilesPanelSummary {
    FilesPanelSummary(
      tree: fileTree(of: id),
      status: statuses[id],
      comparison: changeComparison(of: id),
      tracked: trackedFiles[id] ?? .empty,
    )
  }

  /// The row of the file whose tab is in front of the focused group.
  public func isShownFile(_ row: FileTreeRow, in id: Worktree.ID) -> Bool {
    row.isShown(whenFileInFrontIs: shownFilePath(in: id))
  }

  /// The file whose tab is in front of the focused group, which its row lights.
  func shownFilePath(in id: Worktree.ID) -> String? {
    workspace.activeWorkspaceTab(in: id)?.fileTab?.path
  }
}
