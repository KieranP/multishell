/// A boxed change kept while its tab's view is rebuilt or re-read; a split
/// weighs both sides' finds, each showing half a change.
extension DiffDisplayText: ChangeAnchoring {
  public func anchor(ofChangeAt rows: Range<Int>) -> ChangeAnchor? {
    guard let start = rows.first, lines.indices.contains(start) else { return nil }
    let wordyRow = rows.clamped(to: lines.indices).first { row in
      lines[row].kind != .padding && lines[row].text.contains { $0.isLetter || $0.isNumber }
    }
    return ChangeAnchor(
      committedDigest: committedDigest,
      committedLineAbove: committedLine(above: start),
      committedLineBelow: committedLine(below: rows.upperBound),
      textAbove: text(above: start),
      lineText: wordyRow.map { lines[$0].text },
    )
  }

  /// By committed lines while that side is as it was, else by text, as after a
  /// commit; see Docs/design/files.md.
  public func change(at anchor: ChangeAnchor) -> Range<Int>? {
    hasCommittedSideMoved(since: anchor)
      ? nearestChange(holding: anchor)?.rows
      : change(sharingCommittedLinesWith: anchor)
  }

  /// A commit, checkout or new scope moved the committed side, renumbering it, which no edit
  /// to the file does.
  func hasCommittedSideMoved(since anchor: ChangeAnchor) -> Bool {
    committedDigest != anchor.committedDigest
  }

  /// Under the same unchanged line, with its distance for a split to weigh both
  /// sides.
  func nearestChange(holding anchor: ChangeAnchor) -> (distance: Int, rows: Range<Int>)? {
    guard let lineText = anchor.lineText else { return nil }
    var nearest: (distance: Int, rows: Range<Int>)?
    for start in changeStarts where text(above: start) == anchor.textAbove {
      guard let rows = change(containing: start),
        rows.contains(where: { lines[$0].kind != .padding && lines[$0].text == lineText })
      else { continue }
      let distance = abs(committedLine(above: start) - anchor.committedLineAbove)
      if distance < nearest?.distance ?? .max { nearest = (distance, rows) }
    }
    return nearest
  }

  /// The one sharing most of the anchor's replaced committed lines, or where either
  /// only adds, one meeting the other's gap: after an edit, not one beside it.
  func change(sharingCommittedLinesWith anchor: ChangeAnchor) -> Range<Int>? {
    let pastCommitted = (lines.last { $0.oldNumber != nil }?.oldNumber ?? 0) + 1
    let anchorBelow = anchor.committedLineBelow ?? pastCommitted
    let anchorOnlyAdds = anchorBelow == anchor.committedLineAbove + 1
    var widest: (sharedSpan: Int, rows: Range<Int>)?
    for start in changeStarts {
      let above = committedLine(above: start)
      guard above < anchorBelow else { break }
      guard let rows = change(containing: start) else { continue }
      let below = committedLine(below: rows.upperBound) ?? pastCommitted
      let onlyAdds = below == above + 1
      let sharedSpan = min(below, anchorBelow) - max(above, anchor.committedLineAbove)
      guard sharedSpan > (anchorOnlyAdds || onlyAdds ? 0 : 1) else { continue }
      if sharedSpan > widest?.sharedSpan ?? 0 { widest = (sharedSpan, rows) }
    }
    return widest?.rows
  }

  /// The committed line of the unchanged row a change ends at, `nil` past the end.
  private func committedLine(below end: Int) -> Int? {
    lines.indices.contains(end) ? lines[end].oldNumber : nil
  }

  private func text(above row: Int) -> String? {
    row == 0 ? nil : lines[row - 1].text
  }

  /// The committed line of the unchanged row above `row`, 0 at the top.
  private func committedLine(above row: Int) -> Int {
    row == 0 ? 0 : lines[row - 1].oldNumber ?? 0
  }
}
