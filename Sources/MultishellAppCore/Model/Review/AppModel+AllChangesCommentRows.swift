import MultishellCore

/// Rows picked for a comment in one file of the All changes tab, by a gutter
/// drag or Comment on Lines.
extension AppModel {
  /// Rows of the file view's own, from where a drag started: a file shown whole
  /// reads its Unified lines, any other the document's, stopping at a fold or its last.
  public func openReviewComposer(
    fromRow start: Int,
    toRow end: Int,
    ofSection index: Int,
    side: DiffSide?,
    in tabID: AllChangesTab.ID,
  ) {
    guard let document = allChangesDocument(of: tabID), document.sections.indices.contains(index)
    else { return }
    let section = document.sections[index]
    if section.isShownWhole {
      guard let lines = section.fileText?.lines,
        let selection = ReviewLineSelection(
          from: start,
          to: end,
          in: lines,
          side: nil,
        )
      else { return }
      openReviewComposer(on: selection, ofFile: section.path, in: tabID)
      return
    }
    let first = section.rows.lowerBound
    guard
      let picked = document.lineSelection(
        from: first + start,
        to: first + end,
        side: side,
      )
    else { return }
    openReviewComposer(on: picked.selection, ofFile: picked.path, in: tabID)
  }
}
