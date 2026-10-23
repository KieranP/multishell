/// A boxed change kept while its tab's view is rebuilt or re-read; a split
/// weighs both sides' finds, each showing half a change.
extension DiffDisplayText: ChangeAnchoring {
  public func anchor(ofChangeAt rows: Range<Int>) -> ChangeAnchor? {
    guard let start = rows.first, lines.indices.contains(start) else { return nil }
    let wordyRow = rows.clamped(to: lines.indices).first { row in
      lines[row].kind != .padding && lines[row].text.contains { $0.isLetter || $0.isNumber }
    }
    return ChangeAnchor(
      headDigest: headDigest,
      headLineAbove: headLine(above: start),
      headLineBelow: headLine(below: rows.upperBound),
      textAbove: text(above: start),
      lineText: wordyRow.map { lines[$0].text },
    )
  }

  /// By `HEAD` lines while `HEAD` is as it was, else by text, as after a
  /// commit; see Docs/design/files.md.
  public func change(at anchor: ChangeAnchor) -> Range<Int>? {
    hasHEADMoved(since: anchor)
      ? nearestChange(holding: anchor)?.rows
      : change(sharingHEADLinesWith: anchor)
  }

  /// A commit or checkout changed `HEAD`, renumbering its lines, which no edit
  /// to the file does.
  func hasHEADMoved(since anchor: ChangeAnchor) -> Bool {
    headDigest != anchor.headDigest
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
      let distance = abs(headLine(above: start) - anchor.headLineAbove)
      if distance < nearest?.distance ?? .max { nearest = (distance, rows) }
    }
    return nearest
  }

  /// The one sharing most of the anchor's replaced `HEAD` lines, or where either
  /// only adds, one meeting the other's gap: after an edit, not one beside it.
  func change(sharingHEADLinesWith anchor: ChangeAnchor) -> Range<Int>? {
    let pastHEAD = (lines.last { $0.oldNumber != nil }?.oldNumber ?? 0) + 1
    let anchorBelow = anchor.headLineBelow ?? pastHEAD
    let anchorOnlyAdds = anchorBelow == anchor.headLineAbove + 1
    var widest: (sharedSpan: Int, rows: Range<Int>)?
    for start in changeStarts {
      let above = headLine(above: start)
      guard above < anchorBelow else { break }
      guard let rows = change(containing: start) else { continue }
      let below = headLine(below: rows.upperBound) ?? pastHEAD
      let onlyAdds = below == above + 1
      let sharedSpan = min(below, anchorBelow) - max(above, anchor.headLineAbove)
      guard sharedSpan > (anchorOnlyAdds || onlyAdds ? 0 : 1) else { continue }
      if sharedSpan > widest?.sharedSpan ?? 0 { widest = (sharedSpan, rows) }
    }
    return widest?.rows
  }

  /// The `HEAD` line of the unchanged row a change ends at, `nil` past the end.
  private func headLine(below end: Int) -> Int? {
    lines.indices.contains(end) ? lines[end].oldNumber : nil
  }

  private func text(above row: Int) -> String? {
    row == 0 ? nil : lines[row - 1].text
  }

  /// The `HEAD` line of the unchanged row above `row`, 0 at the top.
  private func headLine(above row: Int) -> Int {
    row == 0 ? 0 : lines[row - 1].oldNumber ?? 0
  }
}
