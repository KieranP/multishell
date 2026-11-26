/// Where a selection lands after a re-read: on the same run of lines, the
/// copy nearest where they were, or nowhere once one of them has gone.
extension DiffDisplayText {
  public func carriedSelection(_ range: Range<Int>, from previous: DiffDisplayText) -> Range<Int>? {
    guard !previous.lines.isEmpty, !lines.isEmpty else { return nil }
    let touched = previous.rows(touching: range)
    let (firstRow, lastRow) = (touched.lowerBound, touched.upperBound)
    let selectedLines = Array(previous.lines[firstRow...lastRow])
    let matches = lines.startsOfOccurrences(of: selectedLines) { line, selected in
      line.kind == selected.kind && line.text == selected.text
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
