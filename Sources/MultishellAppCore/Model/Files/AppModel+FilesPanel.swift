import Foundation
import MultishellCore
import MultishellGitKit

/// The Files panel: what it lists, the switch, the filter and its folders;
/// see Docs/design/files.md.
extension AppModel {
  /// A listing or a change set is built in the render below this many paths, where
  /// a background build would only flash an empty panel; 200,000 took 1.2 s.
  private static var builtInPlaceBelow: Int { 20_000 }

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
    // Read before the cache answers, so a render it answers still redraws on a landing.
    _ = fileTreeBuildLandings
    let landedListing = fileTreeListings[id]
    let landedChanges = fileTreeChanges[id]
    let cached = fileTreeCache[id]
    if let cached, cached.sources == sources,
      !(cached.awaitsListing && pendingFileTreeListings[id] == nil),
      !(cached.awaitsChanges && pendingFileTreeChanges[id] == nil)
    {
      return cached.tree
    }
    // A count moving, as an agent's every save does, keeps the listing.
    let key = FileTreeListing.Key(sources)
    let built =
      [cached?.tree.listing, landedListing].compactMap(\.self)
      .first { $0.key == key }
      ?? smallListing(sources, key: key)
    if built != nil {
      // The tree about to hold it keeps it now; a build still running for other
      // paths lands with nothing waiting for it, a started one not being stoppable.
      fileTreeListings[id] = nil
    } else {
      buildListingInTheBackground(sources, key: key, for: id)
    }
    let listing = built ?? cached?.tree.listing ?? landedListing ?? .empty
    let changes = treeChanges(
      sources,
      repositories: listing.repositories,
      kept: [cached?.tree.changes, landedChanges].compactMap(\.self),
      for: id,
    )
    let tree = FileTree(sources, listing: listing, changes: changes.changes)
    fileTreeCache[id] = FileTreeCacheEntry(
      sources: sources,
      tree: tree,
      awaitsListing: built == nil,
      awaitsChanges: !changes.isBuilt,
    )
    return tree
  }

  /// The changed paths' half, reused while the paths hold; a set too large for a
  /// render is built off the main actor, the last one shown meanwhile.
  private func treeChanges(
    _ sources: FileTreeSources,
    repositories: Set<String>,
    kept: [FileTreeChanges],
    for id: Worktree.ID,
  )
    -> (changes: FileTreeChanges, isBuilt: Bool)
  {
    let paths = FileTreeChanges.paths(changedIn: sources)
    let built =
      kept.first { $0.isBuilt(from: paths, repositories: repositories) }
      ?? (paths.count < Self.builtInPlaceBelow
        ? FileTreeChanges(paths, repositories: repositories) : nil)
    if let built {
      fileTreeChanges[id] = nil
      return (built, true)
    }
    buildChangesInTheBackground(paths, repositories: repositories, for: id)
    return (kept.first ?? .empty, false)
  }

  private func smallListing(
    _ sources: FileTreeSources,
    key: FileTreeListing.Key,
  )
    -> FileTreeListing?
  {
    let paths = key.tracked.paths.count + key.untrackedPaths.count + key.ignoredEntries.count
    guard paths < Self.builtInPlaceBelow else { return nil }
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
      // Sources that moved back while it built leave nothing to show it.
      guard fileTreeCache[id]?.awaitsListing == true else { return }
      fileTreeListings[id] = listing
      fileTreeBuildLandings += 1
    }
  }

  /// One at a time, as a listing's build is.
  private func buildChangesInTheBackground(
    _ paths: Set<String>,
    repositories: Set<String>,
    for id: Worktree.ID,
  ) {
    guard pendingFileTreeChanges[id] == nil else { return }
    pendingFileTreeChanges[id] = Task { @MainActor [weak self] in
      let changes = await runOnDispatch { FileTreeChanges(paths, repositories: repositories) }
      guard let self, !Task.isCancelled else { return }
      pendingFileTreeChanges[id] = nil
      guard fileTreeCache[id]?.awaitsChanges == true else { return }
      fileTreeChanges[id] = changes
      fileTreeBuildLandings += 1
    }
  }
}
