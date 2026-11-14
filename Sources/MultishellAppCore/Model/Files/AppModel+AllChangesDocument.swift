import MultishellCore
import MultishellGitKit

/// What an All changes tab lays out: its files' rows, folds opened, files
/// collapsed; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// Rebuilt only where its inputs moved; `nil` before a read, while hidden, or
  /// until a read against a new base lands, its wait or failure shown instead.
  public func allChangesDocument(of id: AllChangesTab.ID) -> AllChangesDocument? {
    let tab = workspace.allChangesTab(id)
    guard let reading = allChangesReadings[id],
      reading.baseName == tab.flatMap({ fileTabBase(in: $0.worktreeID)?.shortName })
    else { return nil }
    let inputs = AllChangesDocumentInputs(
      reading: reading,
      collapsed: allChangesCollapsedFiles[id] ?? [],
      openedFolds: allChangesOpenedFolds[id] ?? [:],
      reviewComments: tab.map { reviewComments(in: $0.worktreeID) } ?? [],
      reviewComposer: reviewComposers[id],
      scope: tab.map { fileTabScope(in: $0.worktreeID) },
      layout: workspace.fileTabLayout,
    )
    let cached = allChangesDocuments[id]
    if let cached, cached.inputs == inputs { return cached.document }
    let heldOpen = allChangesHeldOpenLines(of: id)
    let document =
      cached.flatMap { $0.laysOut(inputs, holdingOpen: heldOpen) ? $0.document : nil }
      ?? AllChangesDocument(
        reading,
        collapsed: inputs.collapsed,
        heldOpen: heldOpen,
        layout: inputs.layout,
      )
    allChangesDocuments[id] = AllChangesDocumentCacheEntry(
      inputs: inputs,
      heldOpen: heldOpen,
      document: document,
    )
    return document
  }

  /// The header's chevron.
  public func toggleAllChangesFileCollapsed(_ path: String, in id: AllChangesTab.ID) {
    guard workspace.allChangesTab(id) != nil else { return }
    relayingOutAllChanges(id) {
      if allChangesCollapsedFiles[id, default: []].remove(path) == nil {
        allChangesCollapsedFiles[id, default: []].insert(path)
      }
    }
  }

  /// A change to the rows shown: the find runs again over them, and a file it
  /// brings near the screen unread is read.
  func relayingOutAllChanges(_ id: AllChangesTab.ID, _ change: () -> Void) {
    let before = allChangesDocument(of: id).map(SearchedLayout.allChanges)
    change()
    rerunFileFind(in: id, laidOutBefore: before)
    readNearFilesOwed(in: id)
  }

  /// Whether the bar's button expands every file rather than collapsing them.
  public func isEveryAllChangesFileCollapsed(in id: AllChangesTab.ID) -> Bool {
    guard let files = allChangesReadings[id]?.files, !files.isEmpty else { return false }
    let collapsed = allChangesCollapsedFiles[id] ?? []
    return files.allSatisfy { collapsed.contains($0.path) }
  }

  /// The bar's button: every file collapsed, or every one expanded once all are.
  public func toggleEveryAllChangesFileCollapsed(in id: AllChangesTab.ID) {
    guard workspace.allChangesTab(id) != nil, let files = allChangesReadings[id]?.files else {
      return
    }
    relayingOutAllChanges(id) {
      allChangesCollapsedFiles[id] =
        isEveryAllChangesFileCollapsed(in: id) ? [] : Set(files.map(\.path))
    }
  }

  /// A fold's click shows every line it held.
  public func openAllChangesFold(
    _ lines: ClosedRange<Int>,
    of path: String,
    in id: AllChangesTab.ID,
  ) {
    guard workspace.allChangesTab(id) != nil else { return }
    relayingOutAllChanges(id) {
      allChangesOpenedFolds[id, default: [:]][path, default: []].append(
        AllChangesLineSpan(side: .onDisk, lines: lines)
      )
    }
  }

  /// The view's, as it scrolls: the file at the top of the clip.
  public func noteAllChangesTopFile(_ top: AllChangesTopFile?, in id: AllChangesTab.ID) {
    setIfChanged(\.allChangesTopFiles[id], top)
    setIfChanged(\.allChangesLitPaths[id], top?.path)
  }

  public func allChangesTopFile(of id: AllChangesTab.ID) -> AllChangesTopFile? {
    allChangesTopFiles[id]
  }

  /// Uncached, as `layout` though another may be shown: what a find searched
  /// before a switch that came while the tab was hidden.
  func allChangesDocument(
    of id: AllChangesTab.ID,
    laidOutAs layout: FileTabLayout,
  ) -> AllChangesDocument? {
    guard allChangesDocument(of: id) != nil, let reading = allChangesReadings[id] else {
      return nil
    }
    return AllChangesDocument(
      reading,
      collapsed: allChangesCollapsedFiles[id] ?? [],
      heldOpen: allChangesHeldOpenLines(of: id),
      layout: layout,
    )
  }

  /// The lines each file keeps out of its folds: the folds opened, and each
  /// comment's lines with two either side.
  private func allChangesHeldOpenLines(of id: AllChangesTab.ID) -> [String: [AllChangesLineSpan]] {
    let opened = allChangesOpenedFolds[id] ?? [:]
    guard let tab = workspace.allChangesTab(id) else { return opened }
    return opened.merging(allChangesReviewLines(of: tab), uniquingKeysWith: +)
  }
}
