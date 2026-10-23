import AppKit

/// Every row one height at `row × height` below the inset, as the forced
/// fragments hold TextKit 2; the text, tints and gutter all place rows here.
struct DiffRowGeometry {
  /// Above the first row and below the last, as the prototype pads them.
  static let verticalInset: CGFloat = 6
  /// Natural rows are 15 to 18 pt by script; a fixed one a little taller
  /// than the font's own keeps Devanagari's marks inside it.
  private static let lineSpacingFactor: CGFloat = 1.45
  /// What a step to a change leaves above it, so its first row reads in place.
  static let contextRowsAboveAChange = 3
  /// `NSFontManager`'s weights run 0 to 15, 5 being regular.
  private static let regularWeight = 5

  let font: NSFont
  let rowHeight: CGFloat
  /// No printable ASCII character is wider: a proportional file font's `W`
  /// is several of its spaces.
  let widestASCIIAdvance: CGFloat

  /// `fontFamily` `nil`, or one this Mac lacks, is the system monospace.
  init(fontFamily: String?, fontSize: CGFloat) {
    let chosen =
      fontFamily.flatMap { family in
        NSFontManager.shared.font(
          withFamily: family,
          traits: [],
          weight: Self.regularWeight,
          size: fontSize,
        )
      } ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
    font = chosen
    rowHeight = (fontSize * Self.lineSpacingFactor).rounded()
    let printable = (0x20..<0x7F).compactMap { Unicode.Scalar($0).map { String(Character($0)) } }
    widestASCIIAdvance =
      printable.map { ($0 as NSString).size(withAttributes: [.font: chosen]).width }.max() ?? 0
  }

  func top(ofRow row: Int) -> CGFloat {
    Self.verticalInset + CGFloat(row) * rowHeight
  }

  /// The clip's offset that puts `row` at the top, a fraction where one is
  /// cut; row 0 and above keep the inset in view.
  func scrollOffset(puttingAtTop row: Double) -> CGFloat {
    row <= 0 ? 0 : Self.verticalInset + row * rowHeight
  }

  /// Fewer than the context rows in a clip too short for them, or the change
  /// would sit below it and the next step count from above and find it again.
  func rowsAboveAChange(inClipOf height: CGFloat) -> Int {
    min(Self.contextRowsAboveAChange, max(0, Int(height / rowHeight) - 1))
  }

  /// The row at the top of a clip at `offset`, a fraction where one is cut.
  func topRow(atScrollOffset offset: CGFloat) -> Double {
    max(0, (offset - Self.verticalInset) / rowHeight)
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
    let row = ((y - Self.verticalInset) / rowHeight).rounded(rule)
    guard !row.isNaN else { return 0 }
    return Int(min(max(row, 0), CGFloat(count)))
  }

  func documentHeight(rows count: Int) -> CGFloat {
    Self.verticalInset * 2 + CGFloat(count) * rowHeight
  }
}
