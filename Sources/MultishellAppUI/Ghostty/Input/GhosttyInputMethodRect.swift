import Foundation

/// Where an input method draws by the cursor, in libghostty's top-left
/// coordinates, from its IME point; after Ghostty's own `firstRect`.
enum GhosttyInputMethodRect {
  /// For an empty range it is a caret at the range's end, not a span:
  /// dictation's microphone otherwise sat off the cursor (Ghostty #8493).
  static func rect(imePoint: CGRect, range: NSRange, cell: CGSize) -> CGRect {
    let height = max(imePoint.height, cell.height)
    guard range.length == 0, imePoint.width > 0 else {
      return CGRect(x: imePoint.minX, y: imePoint.minY, width: imePoint.width, height: height)
    }
    let caretOffset = cell.width * Double(range.location)
    return CGRect(x: imePoint.minX + caretOffset, y: imePoint.minY, width: 0, height: height)
  }
}
