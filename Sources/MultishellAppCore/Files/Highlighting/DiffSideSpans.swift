/// Two parses for a file tab's rows, the file on disk and `HEAD`'s text, each
/// side's spans mapped onto the rows that show it.
public enum DiffSideSpans {
  /// The text of one side, its lines joined, as the highlighter parses it.
  public static func sideText(of display: DiffDisplayText, side: DiffSide) -> String {
    display.lines.filter { side.shows($0.kind) }.map(\.text).joined(separator: "\n")
  }

  /// The sides worth parsing: `HEAD` only where a removed row shows it alone,
  /// an unchanged or new file being the file on disk throughout.
  public static func parsedSides(of display: DiffDisplayText) -> [DiffSide] {
    display.wholeSides.filter { side in
      side == .onDisk || display.wholeSides == [.committed]
        || display.lines.contains { $0.kind == .removed }
    }
  }

  /// A side's spans moved from its own text onto the rows' text, a span that
  /// crosses a line split at each row it reaches.
  public static func mapped(
    _ spans: [HighlightSpan],
    from side: DiffSide,
    onto display: DiffDisplayText,
  ) -> [HighlightSpan] {
    var rows: [(sideStart: Int, displayRow: Int, length: Int)] = []
    var offset = 0
    for (row, line) in display.lines.enumerated() where side.shows(line.kind) {
      let length = line.text.utf16.count
      rows.append((offset, row, length))
      offset += length + 1
    }
    // Where both sides are parsed, a kept row is the file on disk's to colour.
    let isOnlyRemovedRows = side == .committed && display.wholeSides.contains(.onDisk)
    let takes = { (kind: DiffLine.Kind) in !isOnlyRemovedRows || kind == .removed }
    var mapped: [HighlightSpan] = []
    for span in spans {
      var low = 0
      var high = rows.count
      while low < high {
        let middle = (low + high) / 2
        if rows[middle].sideStart + rows[middle].length < span.range.lowerBound {
          low = middle + 1
        } else {
          high = middle
        }
      }
      var index = low
      while index < rows.count, rows[index].sideStart < span.range.upperBound {
        let row = rows[index]
        let lower = max(span.range.lowerBound, row.sideStart) - row.sideStart
        let upper = min(span.range.upperBound, row.sideStart + row.length) - row.sideStart
        if lower < upper, takes(display.lines[row.displayRow].kind) {
          let start = display.rowStarts[row.displayRow]
          mapped.append(HighlightSpan(range: (start + lower)..<(start + upper), role: span.role))
        }
        index += 1
      }
    }
    return mapped
  }
}
