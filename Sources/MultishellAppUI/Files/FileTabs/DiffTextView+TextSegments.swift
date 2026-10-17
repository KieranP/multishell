import AppKit

extension DiffTextView {
  /// `units` of the shown text as TextKit 2's range, `nil` past its end.
  func textRange(of units: Range<Int>, in layoutManager: NSTextLayoutManager) -> NSTextRange? {
    let document = layoutManager.documentRange.location
    guard let start = layoutManager.location(document, offsetBy: units.lowerBound),
      let end = layoutManager.location(start, offsetBy: units.count)
    else { return nil }
    return NSTextRange(location: start, end: end)
  }

  /// Fills, in the current colour, the glyphs `range` covers, in UTF-16 units
  /// of the shown text; a range on rows not laid out fills nothing.
  func fillTextSegments(of range: Range<Int>, layoutManager: NSTextLayoutManager) {
    guard let textRange = textRange(of: range, in: layoutManager) else { return }
    let origin = textContainerOrigin
    layoutManager.enumerateTextSegments(in: textRange, type: .standard, options: .rangeNotRequired)
    {
      _,
      frame,
      _,
      _ in
      frame.offsetBy(dx: origin.x, dy: origin.y).fill()
      return true
    }
  }
}
