import MultishellCore

/// Highlighting runs over each file's own rows, a parse of a folded slice
/// colouring it wrong, and lands on the rows the document shows of it.
extension AllChangesDocument {
  /// `spans` found over `section`'s file text, Split's left for the committed
  /// side, cut to its shown rows and moved to that side's offsets, in text order.
  func documentSpans(
    _ spans: [HighlightSpan],
    ofSection index: Int,
    side: DiffSide? = nil,
  ) -> [HighlightSpan] {
    let section = sections[index]
    let text = side == .committed ? committedText ?? self.text : self.text
    guard let fileText = section.sideText(on: side), !section.rows.isEmpty else { return [] }
    var placed: [HighlightSpan] = []
    placed.reserveCapacity(spans.count)
    for span in spans where !span.range.isEmpty {
      for fileRow in fileText.rows(touching: span.range) {
        guard let row = section.documentRow(ofFileRow: fileRow) else { continue }
        let part = span.range.clamped(to: fileText.range(ofRow: fileRow))
        guard !part.isEmpty else { continue }
        let shift = text.rowStarts[row] - fileText.rowStarts[fileRow]
        placed.append(HighlightSpan(range: part.shifted(by: shift), role: span.role))
      }
    }
    return placed
  }

  /// The same spans on the file's own slice, for its view in the per-file list;
  /// a file shown whole is its own Unified rows, the parse's own offsets.
  public func sliceSpans(
    _ spans: [HighlightSpan],
    ofSection index: Int,
    side: DiffSide? = nil,
  ) -> [HighlightSpan] {
    guard !sections[index].isShownWhole else { return spans }
    let rows = sections[index].rows
    let text = side == .committed ? committedText ?? self.text : self.text
    guard !rows.isEmpty else { return [] }
    let base = text.rowStarts[rows.lowerBound]
    return documentSpans(spans, ofSection: index, side: side).map { span in
      HighlightSpan(range: span.range.shifted(by: -base), role: span.role)
    }
  }
}
