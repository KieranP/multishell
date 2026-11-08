/// The text a copy takes: a line cut for display goes whole, its mark standing
/// for the rest. See Docs/design/files/file-tabs.md.
extension DiffDisplayText {
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
