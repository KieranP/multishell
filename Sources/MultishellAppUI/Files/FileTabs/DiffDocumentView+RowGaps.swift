import AppKit
import MultishellAppCore

/// The gaps opened under rows, for review cards and the All changes tab's
/// headers and folds, and the scroll held across them.
extension DiffDocumentView {
  /// A card opening elsewhere moves nothing in view, even a card cut by the top.
  func setRowGapsHoldingAnchor(_ gaps: RowGaps) {
    guard textView.geometry.rowGaps != gaps else { return }
    let anchor = scrollAnchor
    setRowGaps(gaps)
    scroll(toAnchor: anchor)
  }

  /// The gaps alone, the scroll left where it is.
  func setRowGaps(_ gaps: RowGaps) {
    guard textView.geometry.rowGaps != gaps else { return }
    textView.setRowGaps(gaps)
    gutter.geometry = textView.geometry
    layOutGapViews()
  }

  /// Within the row and what is left of the gap under it, so a card closing under
  /// the top leaves the rows after it in view.
  func scroll(toAnchor anchor: ScrollAnchor) {
    let geometry = textView.geometry
    let gapBelow = geometry.top(ofRow: anchor.row + 1) - geometry.gapTop(afterRow: anchor.row)
    let offset = min(anchor.offsetBelowRow, geometry.rowHeight + gapBelow)
    let y = geometry.top(ofRow: anchor.row) + offset
    scroll(to: NSPoint(x: scrollOrigin.x, y: y))
  }
}
