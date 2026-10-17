/// Where a selection lands after a re-read: on the same run of lines, the
/// copy nearest where they were, or nowhere once one of them has gone.
extension DiffDisplayText {
  public func carriedSelection(_ range: Range<Int>, from previous: DiffDisplayText) -> Range<Int>? {
    guard !previous.lines.isEmpty, !lines.isEmpty else { return nil }
    let touched = previous.rows(touching: range)
    let (firstRow, lastRow) = (touched.lowerBound, touched.upperBound)
    let selectedLines = previous.lines[firstRow...lastRow]
    guard selectedLines.count <= lines.count else { return nil }
    let matches = (0...(lines.count - selectedLines.count)).filter { start in
      zip(lines[start...], selectedLines).allSatisfy { $0.kind == $1.kind && $0.text == $1.text }
    }
    guard let start = matches.min(by: { abs($0 - firstRow) < abs($1 - firstRow) }) else {
      return nil
    }
    let lowerColumn = range.lowerBound - previous.rowStarts[firstRow]
    let upperColumn = range.upperBound - previous.rowStarts[lastRow]
    let length = string.utf16.count
    let lower = min(rowStarts[start] + lowerColumn, length)
    let upper = min(rowStarts[start + lastRow - firstRow] + upperColumn, length)
    return lower..<max(lower, upper)
  }
}
