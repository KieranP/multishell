import MultishellCore

/// The selected worktree's files as the quick switcher searches them: when it
/// asks for them, and the search it keeps over them.
extension AppModel {
  /// The most a search keeps, which the Files scope lists in full.
  static var quickSwitcherFilesKept: Int { 100 }

  /// The Files scope, or text in All: what lists the selected worktree's files.
  private var quickSwitcherListsFiles: Bool {
    guard let state = quickSwitcher else { return false }
    return state.scope == .files || (state.scope == .all && !QuickSwitcherQuery(state.text).isEmpty)
  }

  /// Returns once the selected worktree's files it lists are read and built, so a
  /// request lists or chooses what a person would see.
  func quickSwitcherFilesRead() async {
    guard quickSwitcherListsFiles, let id = workspace.selectedWorktreeID else { return }
    await pendingTrackedFilesReads[id]?.value
    // A landed listing starts the change set built over its repositories, so the
    // tree is asked again until neither is building.
    while true {
      _ = fileTree(of: id)
      guard let building = pendingFileTreeListings[id] ?? pendingFileTreeChanges[id] else { return }
      await building.value
    }
  }

  /// Once the Files scope or text in All lists them; see quick-switcher.md.
  func readQuickSwitcherFilesOnceListed() {
    guard quickSwitcherListsFiles, let state = quickSwitcher,
      let id = workspace.selectedWorktreeID, trackedFiles[id] == nil, state.filesAskedFor != id
    else { return }
    // Once an opening: a read that failed would fail again on every key.
    quickSwitcher?.filesAskedFor = id
    scheduleTrackedFilesRead(of: id)
  }

  /// The last search's rows again where the text has not moved, kept with the
  /// tree it searched; an agent's report redraws with every path to search.
  func quickSwitcherFileItems(
    _ query: QuickSwitcherQuery,
    in id: Worktree.ID,
  ) -> [QuickSwitcherItem] {
    let tree = fileTree(of: id)
    if let last = fileTreeCache[id]?.quickSwitcherSearch, last.query == query {
      return last.items
    }
    let items = QuickSwitcherFileMatches.paths(query, in: tree, limit: Self.quickSwitcherFilesKept)
      .map { path in
        var item = quickSwitcherFile(path, in: id)
        item.titleOffsets = QuickSwitcherFileMatches.nameOffsets(query, in: item.title)
        return item
      }
    fileTreeCache[id]?.quickSwitcherSearch = QuickSwitcherFileSearch(query: query, items: items)
    return items
  }

  /// The switcher closing lets every kept search go.
  func forgetQuickSwitcherFileSearches() {
    for id in fileTreeCache.keys { fileTreeCache[id]?.quickSwitcherSearch = nil }
  }
}
