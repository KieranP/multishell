/// The boxed change carried across a re-read or a rebuilt view by its file and
/// that file's own anchor, so folds and files above moving keep the box on it.
extension AllChangesDocument: ChangeAnchoring {
  public func anchor(ofChangeAt rows: Range<Int>) -> ChangeAnchor? {
    guard let start = rows.first, let (index, fileRow) = location(ofRow: start),
      let fileText = sections[index].fileText,
      let fileRows = fileText.change(containing: fileRow),
      var anchor = sections[index].fileAnchoring?.anchor(ofChangeAt: fileRows)
    else { return nil }
    anchor.path = sections[index].path
    return anchor
  }

  /// `nil` where its file or the change has gone, or its file is collapsed.
  public func change(at anchor: ChangeAnchor) -> Range<Int>? {
    guard let path = anchor.path, let index = section(at: path),
      let fileRows = sections[index].fileAnchoring?.change(at: anchor),
      let first = sections[index].documentRow(ofFileRow: fileRows.lowerBound),
      let last = sections[index].documentRow(ofFileRow: fileRows.upperBound - 1)
    else { return nil }
    return first..<(last + 1)
  }
}
