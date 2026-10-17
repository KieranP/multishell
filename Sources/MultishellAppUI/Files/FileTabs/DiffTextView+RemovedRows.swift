import AppKit
import MultishellAppCore
import MultishellCore

extension DiffTextView {
  /// `string` holds `units` of the drawn text from `base` on.
  func colorRemovedRows(
    of text: DiffDisplayText,
    in units: Range<Int>,
    of string: NSMutableAttributedString,
    startingAt base: Int,
    theme: Theme,
  ) {
    guard !units.isEmpty, !text.lines.isEmpty else { return }
    let removedText = theme.removedFileText
    for row in text.rows(touching: units) where text.lines[row].kind == .removed {
      let range = text.range(ofRow: row).clamped(to: units)
      string.addAttribute(
        .foregroundColor,
        value: removedText,
        range: NSRange(location: range.lowerBound - base, length: range.count),
      )
    }
  }
}
