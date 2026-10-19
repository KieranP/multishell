/// Two parses for a file tab's rows, the file on disk and `HEAD`'s text, each
/// side's spans mapped onto the rows that show it.
public enum DiffSideSpans {
  /// The sides worth parsing: `HEAD` only where a removed row shows it alone,
  /// an unchanged or new file being the file on disk throughout.
  public static func parsedSides(of display: DiffDisplayText) -> [DiffSide] {
    display.wholeSides.filter { side in
      side == .onDisk || display.wholeSides == [.committed]
        || display.lines.contains { $0.kind == .removed }
    }
  }

  /// The stretches of a side's text whose spans `mapped` keeps, in text order, a run of
  /// removed rows one and none empty; `nil` where it keeps them all.
  public static func keptRanges(of text: DiffSideText) -> [Range<Int>]? {
    guard keepsRemovedRowsAlone(text) else { return nil }
    var ranges: [Range<Int>] = []
    var isAfterRemovedLine = false
    for (range, row) in zip(text.lineRanges, text.displayRows) {
      let isRemoved = text.display.lines[row].kind == .removed
      defer { isAfterRemovedLine = isRemoved }
      guard isRemoved else { continue }
      if isAfterRemovedLine, let last = ranges.last {
        ranges[ranges.count - 1] = last.lowerBound..<range.upperBound
      } else {
        ranges.append(range)
      }
    }
    return ranges.filter { !$0.isEmpty }
  }

  /// A side's spans moved from its own text onto the rows' text, a span that
  /// crosses a line split at each row it reaches.
  public static func mapped(_ spans: [HighlightSpan], from text: DiffSideText) -> [HighlightSpan] {
    let lines = text.lineRanges
    let display = text.display
    let keepsRemovedRowsAlone = Self.keepsRemovedRowsAlone(text)
    let takes = { (kind: DiffLine.Kind) in !keepsRemovedRowsAlone || kind == .removed }
    var mapped: [HighlightSpan] = []
    for span in spans {
      var index = lines.firstIndex(endingAfter: span.range.lowerBound)
      while index < lines.count, lines[index].lowerBound < span.range.upperBound {
        let line = lines[index]
        let row = text.displayRows[index]
        let onLine = span.range.clamped(to: line)
        if !onLine.isEmpty, takes(display.lines[row].kind) {
          let shift = display.rowStarts[row] - line.lowerBound
          mapped.append(HighlightSpan(range: onLine.shifted(by: shift), role: span.role))
        }
        index += 1
      }
    }
    return mapped
  }

  /// Where both sides are parsed, a kept row is the file on disk's to colour.
  private static func keepsRemovedRowsAlone(_ text: DiffSideText) -> Bool {
    text.side == .committed && text.display.wholeSides.contains(.onDisk)
  }
}
