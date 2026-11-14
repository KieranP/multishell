import MultishellCore

/// What an All changes tab lays out: its files' rows, folds opened, files
/// collapsed; see Docs/design/files/all-changes-tab.md.
extension AppModel {
  /// Rebuilt only where the reading, the collapsed files or the lines held
  /// open moved; `nil` before a read or while hidden.
  public func allChangesDocument(of id: AllChangesTab.ID) -> AllChangesDocument? {
    guard let reading = allChangesReadings[id] else { return nil }
    let collapsed = allChangesCollapsedFiles[id] ?? []
    let heldOpen = allChangesHeldOpenLines(of: id)
    let layout = workspace.fileTabLayout
    if let cached = allChangesDocuments[id], cached.collapsed == collapsed,
      cached.heldOpen == heldOpen, cached.layout == layout, cached.reading == reading
    {
      return cached.document
    }
    let document = AllChangesDocument(
      reading,
      collapsed: collapsed,
      heldOpen: heldOpen,
      layout: layout,
    )
    allChangesDocuments[id] = AllChangesDocumentCacheEntry(
      reading: reading,
      collapsed: collapsed,
      heldOpen: heldOpen,
      layout: layout,
      document: document,
    )
    return document
  }

  public func isAllChangesFileCollapsed(_ path: String, in id: AllChangesTab.ID) -> Bool {
    allChangesCollapsedFiles[id]?.contains(path) ?? false
  }

  /// The header's chevron. The find runs again over the rows now shown.
  public func toggleAllChangesFileCollapsed(_ path: String, in id: AllChangesTab.ID) {
    guard workspace.allChangesTab(id) != nil else { return }
    let before = allChangesDocument(of: id)?.text
    if allChangesCollapsedFiles[id, default: []].remove(path) == nil {
      allChangesCollapsedFiles[id, default: []].insert(path)
    }
    rerunFileFind(in: id, laidOutBefore: before)
  }

  /// A fold's click shows every line it held.
  public func openAllChangesFold(
    _ lines: ClosedRange<Int>,
    of path: String,
    in id: AllChangesTab.ID,
  ) {
    guard workspace.allChangesTab(id) != nil else { return }
    let before = allChangesDocument(of: id)?.text
    allChangesOpenedFolds[id, default: [:]][path, default: []].append(
      AllChangesLineSpan(side: .onDisk, lines: lines)
    )
    rerunFileFind(in: id, laidOutBefore: before)
  }

  /// The view's, as it scrolls: the file at the top of the clip.
  public func noteAllChangesTopFile(_ top: AllChangesTopFile?, in id: AllChangesTab.ID) {
    setIfChanged(\.allChangesTopFiles[id], top)
  }

  public func allChangesTopFile(of id: AllChangesTab.ID) -> AllChangesTopFile? {
    allChangesTopFiles[id]
  }

  /// The lines each file keeps out of its folds: the folds opened, and each
  /// comment's lines with two either side.
  private func allChangesHeldOpenLines(of id: AllChangesTab.ID) -> [String: [AllChangesLineSpan]] {
    let opened = allChangesOpenedFolds[id] ?? [:]
    guard let tab = workspace.allChangesTab(id) else { return opened }
    return opened.merging(allChangesReviewLines(of: tab), uniquingKeysWith: +)
  }
}
