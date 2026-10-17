/// A range carried to another layout of the same rows by the file's line,
/// not by content: Unified's removed rows shift where repeated lines sit.
extension DiffDisplayText {
  /// A line this layout lacks, `HEAD`'s on Split's right, gives an empty range
  /// at the next line it has, else the end of the last before it or the text.
  func rangeOnSameLine(_ range: Range<Int>, from previous: DiffDisplayText) -> Range<Int>? {
    guard !previous.lines.isEmpty, !lines.isEmpty else { return nil }
    let row = previous.row(atOffset: range.lowerBound)
    let line = previous.lines[row]
    let target = lines.indices.first { candidate in
      let other = lines[candidate]
      return line.newNumber.map { other.newNumber == $0 }
        ?? (other.newNumber == nil && other.oldNumber == line.oldNumber)
    }
    guard let target else {
      let next = previous.lines[row...].first { $0.newNumber != nil }?.newNumber
      if let nextRow = next.flatMap({ number in
        lines.indices.first { lines[$0].newNumber == number }
      }) {
        return rowStarts[nextRow]..<rowStarts[nextRow]
      }
      let earlier = previous.lines[..<row].last { $0.newNumber != nil }?.newNumber
      let earlierRow = earlier.flatMap { number in
        lines.indices.first { lines[$0].newNumber == number }
      }
      let end = earlierRow.map { self.range(ofRow: $0).upperBound } ?? string.utf16.count
      return end..<end
    }
    guard lines[target].text == line.text else { return nil }
    let start = rowStarts[target] + range.lowerBound - previous.rowStarts[row]
    return start..<(start + range.count)
  }
}
