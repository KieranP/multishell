import MultishellCore

/// A scroll held by the file's line rather than the row: Unified and Split
/// put the same line on different rows.
extension DiffDisplayText {
  /// `row` is the top row, a fraction where one is cut.
  public func scroll(atRow row: Double, x: Double) -> FileTabScroll {
    let top = min(max(Int(row.rounded(.down)), 0), max(lines.count - 1, 0))
    if lines.indices.contains(top), lines[top].newNumber == nil, let line = lines[top].oldNumber {
      return FileTabScroll(
        line: line,
        isCommittedLine: true,
        rowsFromLine: row - Double(top),
        x: x,
      )
    }
    let anchor =
      lines.indices.dropFirst(top).first { lines[$0].newNumber != nil }
      ?? lines.indices.prefix(top).last { lines[$0].newNumber != nil }
    guard let anchor, let line = lines[anchor].newNumber else {
      return FileTabScroll(line: 0, isCommittedLine: false, rowsFromLine: row, x: x)
    }
    return FileTabScroll(
      line: line,
      isCommittedLine: false,
      rowsFromLine: row - Double(anchor),
      x: x,
    )
  }

  /// The top row putting `scroll`'s line back: the first row with that line or
  /// a later one, by the committed side's numbering where the file's has none.
  public func row(of scroll: FileTabScroll) -> Double {
    guard scroll.line > 0 else { return max(0, scroll.rowsFromLine) }
    let byDisk = { (index: Int) in (lines[index].newNumber ?? 0) >= scroll.line }
    let byCommittedLine = { (index: Int) in (lines[index].oldNumber ?? 0) >= scroll.line }
    let anchor =
      scroll.isCommittedLine
      ? lines.indices.first(where: byCommittedLine)
      : lines.indices.first(where: byDisk) ?? lines.indices.first(where: byCommittedLine)
    return max(0, Double(anchor ?? max(lines.count - 1, 0)) + scroll.rowsFromLine)
  }
}
