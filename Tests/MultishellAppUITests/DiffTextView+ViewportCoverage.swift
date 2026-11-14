import AppKit

@testable import MultishellAppCore
@testable import MultishellAppUI

extension DiffTextView {
  /// The rows on screen TextKit's viewport leaves out, which it draws no glyphs for.
  var visibleRowsOutsideTheViewport: ClosedRange<Int>? {
    guard let layoutManager = textLayoutManager,
      let viewport = layoutManager.textViewportLayoutController.viewportRange
    else { return nil }
    let first = layoutManager.offset(
      from: layoutManager.documentRange.location,
      to: viewport.location,
    )
    let last = layoutManager.offset(
      from: layoutManager.documentRange.location,
      to: viewport.endLocation,
    )
    let shown = geometry.rows(in: visibleRect, count: displayText.lines.count)
    guard let top = shown.first, let bottom = shown.last else { return nil }
    let covered =
      displayText.row(atOffset: first)...displayText.row(atOffset: max(first, last - 1))
    return covered.contains(top) && covered.contains(bottom) ? nil : top...bottom
  }
}
