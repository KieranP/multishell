import Foundation

/// Where an input method draws by the cursor, in libghostty's top-left
/// coordinates, from its IME point; after Ghostty's own `firstRect`.
enum GhosttyInputMethodRect {
  /// With nothing marked it is a caret at the range's end, not a span:
  /// dictation's microphone otherwise sat off the cursor (Ghostty #8493).
  static func rect(imePoint: CGRect, range: NSRange, cell: CGSize) -> CGRect {
    let isCaret = range.length == 0 && imePoint.width > 0
    let caretOffset = cell.width * Double(range.location + range.length)
    return CGRect(
      x: isCaret ? imePoint.minX + caretOffset : imePoint.minX, y: imePoint.minY,
      width: isCaret ? 0 : imePoint.width, height: max(imePoint.height, cell.height))
  }
}
