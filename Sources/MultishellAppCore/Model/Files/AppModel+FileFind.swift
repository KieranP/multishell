import MultishellCore

/// The find bar over a file tab, searched in its rows rather than by the
/// engine; see Docs/design/files.md. `AppModel+Find` routes a file tab here.
extension AppModel {
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
    laidOutBefore previousText: DiffDisplayText? = nil,
  ) {
    // A hidden tab's rows are let go; its result waits for the read on show,
    // a new search starting over then.
    if fileTabReadings[id]?.content.isReleased == true, !text.isEmpty {
      if !keepingSelection {
        setIfChanged(
          \.fileFindResults[id],
          FileFindResult.awaitingRows(after: fileFindResults[id]),
        )
      }
      return
    }
    guard !text.isEmpty, let searched = searchedText(of: id) else {
      setIfChanged(\.fileFindResults[id], nil)
      return
    }
    var previous = fileFindResults[id]
    if let previousText { previous = previous?.carried(from: previousText, to: searched) }
    var result = FileFindResult.searching(
      text,
      in: searched,
      after: previous,
      keepingSelection: keepingSelection,
    )
    result.isSearchedInSplit = workspace.fileTab(id).flatMap(shownSplit(of:)) != nil
    setIfChanged(\.fileFindResults[id], result)
  }

  /// What find searches in a tab: a split's right side, the file on disk.
  func searchedText(of id: FileTab.ID) -> DiffDisplayText? {
    guard let tab = workspace.fileTab(id), case .text(let rows) = fileTabReadings[id]?.content
    else { return nil }
    return shownSplit(of: tab)?.onDisk ?? rows.displayText
  }

  func stepFileFind(_ direction: CycleDirection, in id: FileTab.ID) {
    fileFindResults[id]?.step(direction)
  }

  /// A re-read moves the text under a search, so its matches are found again.
  func rerunFileFind(in id: FileTab.ID, laidOutBefore previousText: DiffDisplayText? = nil) {
    guard findBarTargetIDs.contains(id) else { return }
    runFileFind(
      for: findText(of: id),
      in: id,
      keepingSelection: true,
      laidOutBefore: previousText ?? otherLayoutSearched(in: id),
    )
  }

  /// The other layout's text where the result was searched in it, a switch
  /// having come while the tab was hidden and its rows let go.
  private func otherLayoutSearched(in id: FileTab.ID) -> DiffDisplayText? {
    guard let result = fileFindResults[id], let tab = workspace.fileTab(id),
      case .text(let rows) = fileTabReadings[id]?.content,
      result.isSearchedInSplit != (shownSplit(of: tab) != nil)
    else { return nil }
    return result.isSearchedInSplit ? rows.split?.onDisk : rows.displayText
  }
}
