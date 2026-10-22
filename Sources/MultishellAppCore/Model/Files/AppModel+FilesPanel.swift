import Foundation
import MultishellCore
import MultishellGitKit

/// The Files panel: what it lists, the switch, the filter and its folders;
/// see Docs/design/files.md.
extension AppModel {
  /// Built in the render below this many paths, where a background build
  /// would only flash an empty panel; 200,000 took 1.2 s.
  private static var listingBuiltInPlaceBelow: Int { 20_000 }

  /// The worktree the panel lists, where the panel can be: a worktree with
  /// tabs or with none, not an operation or a cover.
  public var filesPanelWorktree: Worktree? {
    switch detailContent {
    case .noTabs(let worktree), .tabGroups(let worktree): worktree
    case .cover, .noSelection, .operation: nil
    }
  }

  /// Open, and with a worktree to list: what both edges' widths allow for.
  public var isFilesPanelOnScreen: Bool { showsFilesPanel && filesPanelWorktree != nil }

  /// The header glyph's and the View menu's; shut at each launch.
  public func setShowsFilesPanel(_ shows: Bool) {
    guard showsFilesPanel != shows else { return }
    showsFilesPanel = shows
    if shows, let worktree = filesPanelWorktree {
      readFilesPanel(of: worktree.id)
    } else if !shows {
      forgetPanelListings { _ in true }
    }
  }

  public func toggleFilesPanel() {
    setShowsFilesPanel(!showsFilesPanel)
  }

  /// A click on a worktree row's git badge: that worktree, the panel open on
  /// what changed there.
  public func showModifiedFiles(of worktree: Worktree) {
    if workspace.selectedWorktreeID != worktree.id || detailCover != nil {
      guard select(worktree) else { return }
    }
    setFilesPanelMode(.modified)
    filesPanelStates[worktree.id]?.filterText = ""
    setShowsFilesPanel(true)
  }

  public func filesPanelState(of id: Worktree.ID) -> FilesPanelState {
    var state = filesPanelStates[id] ?? FilesPanelState()
    state.mode = workspace.filesPanelMode
    return state
  }

  /// The panel's switch, kept for every worktree's panel and the next launch.
  public func setFilesPanelMode(_ mode: FilesPanelMode) {
    guard workspace.filesPanelMode != mode else { return }
    store.setFilesPanelMode(mode)
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
    case .all:
      if state.expandedFolders.remove(path) == nil {
        state.expandedFolders.insert(path)
        if row.isRepository { scheduleSubmoduleRead(path, in: id) }
        if row.isIgnored { scheduleIgnoredFolderRead(path, in: id) }
      }

    case .modified:
      if state.collapsedModifiedFolders.remove(path) == nil {
        state.collapsedModifiedFolders.insert(path)
      }
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
      tracked: trackedFiles[id] ?? .empty,
    )
  }

  /// The row of the file whose tab is in front of the focused group.
  public func isShownFile(_ row: FileTreeRow, in id: Worktree.ID) -> Bool {
    !row.isFolder && workspace.activeWorkspaceTab(in: id)?.fileTab?.path == row.path
  }

  /// Built only where something it is built from moved since the last; the
  /// listing only where paths moved, and the last one shown while it builds.
  func fileTree(of id: Worktree.ID) -> FileTree {
    let sources = FileTreeSources(
      tracked: trackedFiles[id] ?? .empty,
      status: statuses[id],
      submodules: submoduleReadings[id] ?? [:],
      ignoredEntries: ignoredEntries[id] ?? [],
      ignoredFolderEntries: ignoredFolderEntries[id] ?? [:],
    )
    let cached = fileTreeCache[id]
    if let cached, cached.sources == sources,
      !cached.awaitsListing || pendingFileTreeListings[id] != nil
    {
      return cached.tree
    }
    // A count moving, as an agent's every save does, keeps the listing.
    let key = FileTreeListing.Key(sources)
    if let listing = [cached?.tree.listing, fileTreeListings[id]].compactMap(\.self)
      .first(where: { $0.key == key })
      ?? smallListing(sources, key: key)
    {
      // A build for other paths would only land a listing nothing shows.
      pendingFileTreeListings.removeValue(forKey: id)?.cancel()
      let tree = FileTree(sources, listing: listing, reusingChangesOf: cached?.tree)
      fileTreeCache[id] = FileTreeCacheEntry(sources: sources, tree: tree)
      return tree
    }
    buildListingInTheBackground(sources, key: key, for: id)
    let shown = cached?.tree.listing ?? fileTreeListings[id] ?? .empty
    let tree = FileTree(sources, listing: shown, reusingChangesOf: cached?.tree)
    fileTreeCache[id] = FileTreeCacheEntry(sources: sources, tree: tree, awaitsListing: true)
    return tree
  }

  private func smallListing(
    _ sources: FileTreeSources,
    key: FileTreeListing.Key,
  )
    -> FileTreeListing?
  {
    let paths = key.tracked.paths.count + key.untrackedPaths.count + key.ignoredEntries.count
    guard paths < Self.listingBuiltInPlaceBelow else { return nil }
    return FileTreeListing(sources, key: key)
  }

  /// A started build cannot be stopped, so another waits for it to land; the
  /// redraw its landing sets off asks for the newest key.
  private func buildListingInTheBackground(
    _ sources: FileTreeSources,
    key: FileTreeListing.Key,
    for id: Worktree.ID,
  ) {
    guard pendingFileTreeListings[id] == nil else { return }
    pendingFileTreeListings[id] = Task { @MainActor [weak self] in
      let listing = await runOnDispatch {
        let started = ContinuousClock.now
        var listing = FileTreeListing(sources, key: key)
        listing.buildCost = started.duration(to: .now)
        return listing
      }
      guard let self, !Task.isCancelled else { return }
      pendingFileTreeListings[id] = nil
      fileTreeListings[id] = listing
    }
  }
}
