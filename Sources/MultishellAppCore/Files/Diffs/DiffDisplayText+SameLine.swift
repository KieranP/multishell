/// A range carried to another layout of the same rows by the file's line,
/// not by content: Unified's removed rows shift where repeated lines sit.
extension DiffDisplayText {
  /// A line this layout lacks gives an empty range at the next line it has, else the
  /// end of the last before it; `rows` hold the search to one file of several.
  func rangeOnSameLine(
    _ range: Range<Int>,
    from previous: DiffDisplayText,
    inRows rows: Range<Int>? = nil,
    fromRows previousRows: Range<Int>? = nil,
  ) -> Range<Int>? {
    let rows = rows ?? lines.indices
    let previousRows = previousRows ?? previous.lines.indices
    guard !previousRows.isEmpty, !rows.isEmpty else { return nil }
    let row = previous.row(atOffset: range.lowerBound)
    guard previousRows.contains(row) else { return nil }
    let line = previous.lines[row]
    let target = rows.first { candidate in
      let other = lines[candidate]
      return line.newNumber.map { other.newNumber == $0 }
        ?? (other.newNumber == nil && other.oldNumber == line.oldNumber)
    }
    guard let target else {
      let next = previous.lines[row..<previousRows.upperBound].first { $0.newNumber != nil }
      if let nextRow = next?.newNumber.flatMap({ number in
        rows.first { lines[$0].newNumber == number }
      }) {
        return rowStarts[nextRow]..<rowStarts[nextRow]
      }
      let earlier = previous.lines[previousRows.lowerBound..<row].last { $0.newNumber != nil }
      let earlierRow = earlier?.newNumber.flatMap { number in
        rows.first { lines[$0].newNumber == number }
      }
      let end = self.range(ofRow: earlierRow ?? rows.upperBound - 1).upperBound
      return end..<end
    }
    guard lines[target].text == line.text else { return nil }
    return range.shifted(by: rowStarts[target] - previous.rowStarts[row])
  }
}
