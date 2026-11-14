import MultishellCore

/// The gutter's + and Comment on Lines in the All changes tab: the rows picked
/// read as one file's lines, that of the row the drag started on.
extension AllChangesDocument {
  /// Rows past that file's are left out, a comment never spanning two files.
  public func lineSelection(
    from start: Int,
    to end: Int,
    side: DiffSide?,
  ) -> (selection: ReviewLineSelection, path: String)? {
    guard let index = section(atRow: start) else { return nil }
    let file = sections[index]
    guard let fileText = file.sideText(on: side), !file.rows.isEmpty else { return nil }
    let clamped = { (row: Int) in min(max(row, file.rows.lowerBound), file.rows.upperBound - 1) }
    guard let fileStart = file.fileRow(ofDocumentRow: clamped(start)),
      let fileEnd = file.fileRow(ofDocumentRow: clamped(end)),
      let selection = ReviewLineSelection(
        from: fileStart,
        to: fileEnd,
        in: fileText.lines,
        side: side,
      )
    else { return nil }
    return (selection, file.path)
  }
}
