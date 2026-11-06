/// A file tab's rows for text git diffs as no change, or as every line new.
enum PlainDiffLines {
  /// One row per line, a final newline closing the last rather than opening
  /// another.
  static func of(_ text: String, kind: DiffLine.Kind) -> [DiffLine] {
    var parts = text.lines()
    if parts.last?.isEmpty == true { parts.removeLast() }
    return parts.enumerated().map { index, part in
      let number = index + 1
      return DiffLine(
        kind: kind,
        oldNumber: kind == .context ? number : nil,
        newNumber: number,
        text: String(part),
      )
    }
  }
}
