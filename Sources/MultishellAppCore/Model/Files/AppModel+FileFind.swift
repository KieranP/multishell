import MultishellCore

/// The find bar over a file or All changes tab, searched in its rows rather
/// than by the engine; see Docs/design/files/file-tabs.md.
extension AppModel {
  /// A file or All changes tab: its rows are searched here, a pane's by the engine.
  func searchesRowsInModel(_ id: FindTargetID) -> Bool {
    switch workspace.workspaceTab(id) {
    case .allChanges, .file: true
    case .terminal, nil: false
    }
  }

  /// While its bar is up; the view highlights each.
  public func fileFindMatches(of id: FileTab.ID) -> [Range<Int>] {
    findBarTargetIDs.contains(id) ? fileFindResults[id]?.matches ?? [] : []
  }

  public func selectedFileFindMatch(of id: FileTab.ID) -> Int? {
    findBarTargetIDs.contains(id) ? fileFindResults[id]?.selected : nil
  }

  /// Changes only where the view should select and scroll to the match.
  public func fileFindSelectionMoves(of id: FileTab.ID) -> Int {
    fileFindResults[id]?.selectionMoves ?? 0
  }

  /// The view's, once it has drawn a tab's find, for the view rebuilt after it.
  public func noteFileFindShown(_ shown: FileFindShown, of id: FileTab.ID) {
    fileFindsShown[id] = shown
  }

  public func fileFindShown(of id: FileTab.ID) -> FileFindShown? {
    fileFindsShown[id]
  }

  /// The tab's text view's, as its selection changes, for Cmd+F to find.
  public func noteFileTabSelection(_ text: String?, of id: FileTab.ID) {
    fileTabSelections[id] = text
  }

  /// An empty find text counts nothing, as a pane's does; a split is searched
  /// on its right side, the file on disk.
  func runFileFind(
    for text: String,
    in id: FileTab.ID,
    keepingSelection: Bool = false,
    laidOutBefore previousLayout: SearchedLayout? = nil,
  ) {
    // A hidden tab's rows are let go; its result waits for the read on show,
    // a new search starting over then.
    if isAwaitingRowsToFind(id), !text.isEmpty {
      if !keepingSelection {
        setIfChanged(
          \.fileFindResults[id],
          FileFindResult.awaitingRows(after: fileFindResults[id]),
        )
      }
      return
    }
    guard !text.isEmpty, let searched = searchedLayout(of: id) else {
      setIfChanged(\.fileFindResults[id], nil)
      return
    }
    var previous = fileFindResults[id]
    if let previousLayout { previous = previous?.carried(from: previousLayout, to: searched) }
    var result = FileFindResult.searching(
      text,
      in: searched,
      after: previous,
      keepingSelection: keepingSelection,
    )
    result.isSearchedInSplit = showsSplit(id)
    setIfChanged(\.fileFindResults[id], result)
  }

  /// What find searches in a tab: a split's right side, the file on disk; the
  /// All changes tab's shown rows.
  func searchedLayout(of id: FindTargetID) -> SearchedLayout? {
    switch workspace.workspaceTab(id) {
    case .file(let tab):
      guard case .text(let rows) = fileTabReadings[id]?.content else { return nil }
      return .fileText(shownSplit(of: tab)?.onDisk ?? rows.displayText)

    case .allChanges: return allChangesDocument(of: id).map(SearchedLayout.allChanges)
    case .terminal, nil: return nil
    }
  }

  /// A hidden tab's rows are let go, so its find waits for the read on show;
  /// an All changes tab's read under another base waits for the new base's.
  private func isAwaitingRowsToFind(_ id: FindTargetID) -> Bool {
    switch workspace.workspaceTab(id) {
    case .file: fileTabReadings[id]?.content.isReleased == true
    case .allChanges: allChangesDocument(of: id) == nil
    case .terminal, nil: false
    }
  }

  func stepFileFind(_ direction: CycleDirection, in id: FileTab.ID) {
    fileFindResults[id]?.step(direction)
  }

  /// A re-read moves the text under a search, so its matches are found again.
  func rerunFileFind(in id: FileTab.ID, laidOutBefore previousLayout: SearchedLayout? = nil) {
    guard findBarTargetIDs.contains(id) else { return }
    runFileFind(
      for: findText(of: id),
      in: id,
      keepingSelection: true,
      laidOutBefore: previousLayout ?? otherLayoutSearched(in: id),
    )
  }

  /// The other layout's text where the result was searched in it, a switch
  /// having come while the tab was hidden and its rows let go.
  private func otherLayoutSearched(in id: FindTargetID) -> SearchedLayout? {
    guard let result = fileFindResults[id], result.isSearchedInSplit != showsSplit(id) else {
      return nil
    }
    switch workspace.workspaceTab(id) {
    case .file:
      guard case .text(let rows) = fileTabReadings[id]?.content else { return nil }
      return (result.isSearchedInSplit ? rows.split?.onDisk : rows.displayText)
        .map(SearchedLayout.fileText)

    case .allChanges:
      return allChangesDocument(of: id, laidOutAs: result.isSearchedInSplit ? .split : .unified)
        .map(SearchedLayout.allChanges)

    case .terminal, nil:
      return nil
    }
  }

  private func showsSplit(_ id: FindTargetID) -> Bool {
    switch workspace.workspaceTab(id) {
    case .file(let tab): shownSplit(of: tab) != nil
    case .allChanges: workspace.fileTabLayout == .split
    case .terminal, nil: false
    }
  }
}
