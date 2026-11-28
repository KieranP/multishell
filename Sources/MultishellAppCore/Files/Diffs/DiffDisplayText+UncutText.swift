/// The text a copy takes: a line cut for display goes whole, its mark standing
/// for the rest. See Docs/design/files/file-tabs.md.
extension DiffDisplayText {
  /// Every row's line whole, for what quotes or keeps a line rather than draws it.
  var uncutLines: [DiffLine] {
    cutRemainders.isEmpty ? lines : lines.indices.map(uncutLine(ofRow:))
  }

  /// The row's line whole, for a text built from this one's rows, which cuts
  /// it again and so still copies it whole.
  func uncutLine(ofRow row: Int) -> DiffLine {
    let line = lines[row]
    guard cutRemainders[row] != nil else { return line }
    return DiffLine(
      kind: line.kind,
      oldNumber: line.oldNumber,
      newNumber: line.newNumber,
      text: uncutText(ofRow: row),
      isStaged: line.isStaged,
      changedParts: line.changedParts,
    )
  }

  func uncutText(ofRow row: Int) -> String {
    guard let remainder = cutRemainders[row] else { return lines[row].text }
    return lines[row].text.dropLast() + remainder
  }

  /// `text(in:)` with each cut line's mark the range takes put back as its rest.
  func uncutText(in range: Range<Int>) -> String {
    var copied = ""
    var cursor = range.lowerBound
    for row in rows(touching: range) {
      guard let remainder = cutRemainders[row] else { continue }
      let mark = self.range(ofRow: row).upperBound - 1
      guard range.contains(mark) else { continue }
      copied += text(in: cursor..<mark) + remainder
      cursor = mark + 1
    }
    return copied + text(in: cursor..<range.upperBound)
  }
}
