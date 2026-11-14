import MultishellCore

/// A scroll held by the file at the top and its line there, so folds opening
/// and files coming or going above keep the place.
extension AllChangesDocument {
  /// `row` is the top row, a fraction where one is cut; `nil` with no files.
  public func scroll(atRow row: Double, x: Double) -> AllChangesScroll? {
    let top = Int(row.rounded(.down))
    guard let section = section(atRow: top) else { return nil }
    let file = sections[section]
    guard let fileText = file.fileText, let fileRow = file.fileRow(ofDocumentRow: top) else {
      return AllChangesScroll(
        path: file.path,
        scroll: FileTabScroll(line: 0, isCommittedLine: false, rowsFromLine: 0, x: x),
      )
    }
    let fileTop = Double(fileRow) + row - Double(top)
    let split = file.fileCommittedText.map { SplitDiff(committed: $0, onDisk: fileText) }
    return AllChangesScroll(
      path: file.path,
      scroll: split?.scroll(atRow: fileTop, x: x) ?? fileText.scroll(atRow: fileTop, x: x),
    )
  }

  /// The top row putting `scroll` back: its line's row, else the next shown in
  /// that file, else the file's first; `nil` where the file has gone.
  public func row(of scroll: AllChangesScroll) -> Double? {
    guard let index = section(at: scroll.path) else { return nil }
    let file = sections[index]
    guard let fileText = file.fileText, !file.rows.isEmpty else {
      return Double(file.rows.lowerBound)
    }
    // Split numbers a removed line by the left side, which holds it.
    let byLine = scroll.scroll.isCommittedLine ? file.fileCommittedText ?? fileText : fileText
    let fileRow = byLine.row(of: scroll.scroll)
    let whole = Int(fileRow.rounded(.down))
    guard let row = file.documentRow(atOrAfterFileRow: whole) else {
      return Double(file.rows.upperBound - 1)
    }
    return Double(row) + (file.documentRow(ofFileRow: whole) == row ? fileRow - Double(whole) : 0)
  }
}
