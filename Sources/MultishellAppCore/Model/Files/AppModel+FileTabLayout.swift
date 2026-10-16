import MultishellCore

extension AppModel {
  /// The two sides a split tab shows, `nil` for one shown Unified: what the
  /// view draws and the find searches, so their offsets agree.
  public func shownSplit(of tab: FileTab) -> SplitDiff? {
    guard layout(of: tab) == .split, case .text(let rows) = fileTabReadings[tab.id]?.content
    else { return nil }
    return rows.split
  }

  /// The chosen layout, but Unified where the bar offers no switch.
  public func layout(of tab: FileTab) -> FileTabLayout {
    offersLayoutSwitch(for: tab) ? workspace.fileTabLayout : .unified
  }

  /// Only where there is something to put side by side: lines both added and
  /// removed, the user's rule, so a new or emptied file stays Unified.
  public func offersLayoutSwitch(for tab: FileTab) -> Bool {
    guard case .text(let rows) = fileTabReadings[tab.id]?.content, !rows.hasModeChange else {
      return false
    }
    return rows.split != nil && rows.lineCounts.showsInsertions && rows.lineCounts.showsDeletions
  }

  /// The bar's Unified / Split switch, kept for every tab. The find runs
  /// again over the text now shown, its selection carried by line.
  public func setFileTabLayout(_ layout: FileTabLayout) {
    guard workspace.fileTabLayout != layout else { return }
    let searchedBefore = workspace.fileTabs.map { ($0.id, searchedText(of: $0.id)) }
    store.setFileTabLayout(layout)
    for (id, text) in searchedBefore { rerunFileFind(in: id, laidOutBefore: text) }
  }
}
