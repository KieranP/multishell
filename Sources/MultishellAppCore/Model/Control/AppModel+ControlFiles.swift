import MultishellCore

/// The Files panel as it lists the worktree in view; a page that lists no files,
/// the panel shut or its window off screen is refused, its rows read only while it shows.
extension AppModel {
  /// No worktree to list is said before the panel: opening it would not give one.
  private func reachListedFilesWorktree() throws(ControlRefusal) -> Worktree {
    if let refusal = refusalToReadInWorkspaceWindow { throw refusal }
    guard let worktree = filesPanelWorktree else { throw .nothingInView }
    guard isFileListOnScreen else { throw .filesPanelListsNoFiles }
    return worktree
  }

  func replyToListFiles() -> ControlReply {
    let worktree: Worktree
    do { worktree = try reachListedFilesWorktree() } catch { return .refused(error) }
    let id = worktree.id
    let state = filesPanelState(of: id)
    // Built first: building them is what starts a listing that is out of date.
    let rows = fileTreeRows(of: id)
    let cached = fileTreeCache[id]
    let shownPath = shownFilePath(in: id)
    return .json(
      FilesListing(
        worktree: ControlID.worktree(id),
        page: state.mode.commandName,
        changeScope: state.mode == .changes ? workspace.changeScope : nil,
        filterText: state.filterText,
        isReading: pendingTrackedFilesReads[id] != nil || pendingStatusRefreshes[id] != nil
          || panelFolderReads.isRunning { $0.worktreeID == id }
          || branchChangesReads.isRunning(id) || changeComparison(of: id) == .unread
          || cached?.awaitsListing == true || cached?.awaitsChanges == true,
        rows: rows.map { row in
          FilesListing.Row(
            path: row.path,
            name: row.name,
            parentFolder: row.parentFolder,
            depth: row.depth,
            isFolder: row.isFolder,
            isExpanded: row.isExpanded,
            change: row.changeKind?.commandName,
            insertions: row.lineCounts?.insertions,
            deletions: row.lineCounts?.deletions,
            isIgnored: row.isIgnored,
            isShown: row.isShown(whenFileInFrontIs: shownPath),
          )
        },
      )
    )
  }

  /// As typed into the panel's field; empty clears it.
  func replyToFilterFiles(_ text: String) -> ControlReply {
    let worktree: Worktree
    do { worktree = try reachListedFilesWorktree() } catch { return .refused(error) }
    setFilesPanelFilterText(text, in: worktree.id)
    return replyToListFiles()
  }

  /// The folder's chevron, where it is not already that way.
  func replyToSetFilesFolderExpanded(_ path: String, expanded: Bool) -> ControlReply {
    let worktree: Worktree
    do { worktree = try reachListedFilesWorktree() } catch { return .refused(error) }
    guard let row = fileTreeRows(of: worktree.id).first(where: { $0.isFolder && $0.path == path })
    else { return .refused(.noFilesFolder(path: path)) }
    if row.isExpanded != expanded { toggleFolder(row, in: worktree.id) }
    return replyToListFiles()
  }
}
