import AppKit

/// Every row one height at `row × height` below the inset, as the forced fragments hold
/// TextKit 2, plus the review card gaps above it. Text, tints and gutter place rows here.
struct DiffRowGeometry {
  /// Above the first row and below the last, as the prototype pads them.
  static let verticalInset: CGFloat = 6
  /// Natural rows are 15 to 18 pt by script; a fixed one a little taller
  /// than the font's own keeps Devanagari's marks inside it.
  private static let lineSpacingFactor: CGFloat = 1.45
  /// What a step to a change leaves above it, so its first row reads in place.
  static let contextRowsAboveAChange = 3

  let font: NSFont
  let rowHeight: CGFloat
  /// No printable ASCII character is wider: a proportional file font's `W`
  /// is several of its spaces.
  let widestASCIIAdvance: CGFloat
  var rowGaps = RowGaps.empty

  /// `fontFamily` `nil`, or one this Mac lacks, is the system monospace.
  init(fontFamily: String?, fontSize: CGFloat) {
    let chosen =
      fontFamily.flatMap { NSFont.regular(ofFamily: $0, size: fontSize) }
      ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    font = chosen
    rowHeight = (fontSize * Self.lineSpacingFactor).rounded()
    let printable = (0x20..<0x7F).compactMap { Unicode.Scalar($0).map { String(Character($0)) } }
    widestASCIIAdvance =
      printable.map { ($0 as NSString).size(withAttributes: [.font: chosen]).width }.max() ?? 0
  }

  func top(ofRow row: Int) -> CGFloat {
    Self.verticalInset + CGFloat(row) * rowHeight + rowGaps.heightAbove(row: row)
  }

  /// From the first row's top to the last's bottom, any gap between them included.
  func height(ofRows rows: Range<Int>) -> CGFloat {
    guard let last = rows.last else { return 0 }
    return top(ofRow: last) + rowHeight - top(ofRow: rows.lowerBound)
  }

  /// Where the gap under `row` starts, just below the row.
  func gapTop(afterRow row: Int) -> CGFloat {
    top(ofRow: row) + rowHeight
  }

  /// The clip's offset that puts `row` at the top, a fraction where one is
  /// cut; row 0 and above keep the inset in view.
  func scrollOffset(puttingAtTop row: Double) -> CGFloat {
    guard row > 0 else { return 0 }
    return Self.verticalInset + row * rowHeight + rowGaps.heightAbove(row: Int(row))
  }

  /// The clip's offset putting `row` `rowsAbove` rows' height under the top, by
  /// points: a card's gap among those rows would push it below a short clip.
  func scrollOffset(putting row: Int, rowsBelowTop rowsAbove: Int) -> CGFloat {
    let offset = top(ofRow: row) - CGFloat(rowsAbove) * rowHeight
    // Near the top the inset stays in view, unless a gap above pushed the row down.
    return row > rowsAbove ? offset : max(0, offset - Self.verticalInset)
  }

  /// Fewer than the context rows in a clip too short for them, or the change
  /// would sit below it and the next step count from above and find it again.
  func rowsAboveAChange(inClipOf height: CGFloat) -> Int {
    min(Self.contextRowsAboveAChange, max(0, Int(height / rowHeight) - 1))
  }

  /// The row at the top of a clip at `offset`, a fraction where one is cut.
  func topRow(atScrollOffset offset: CGFloat) -> Double {
    max(0, rowGaps.row(atContentY: offset - Self.verticalInset, rowHeight: rowHeight))
  }

  /// The rows a rect in the document reaches, clamped to `count`: a rect
  /// missing the view is `NSRect.null`, its origin infinite, which trapped.
  func rows(in rect: NSRect, count: Int) -> Range<Int> {
    guard count > 0, !rect.isNull else { return 0..<0 }
    let first = row(atY: rect.minY, rounded: .down, count: count)
    let last = row(atY: rect.maxY, rounded: .up, count: count)
    return first..<max(last, first)
  }

  private func row(atY y: CGFloat, rounded rule: FloatingPointRoundingRule, count: Int) -> Int {
    guard !y.isNaN else { return 0 }
    let row = rowGaps.row(atContentY: y - Self.verticalInset, rowHeight: rowHeight).rounded(rule)
    guard !row.isNaN else { return 0 }
    return Int(min(max(row, 0), Double(count)))
  }

  func documentHeight(rows count: Int) -> CGFloat {
    Self.verticalInset * 2 + CGFloat(count) * rowHeight + rowGaps.total
  }
}
